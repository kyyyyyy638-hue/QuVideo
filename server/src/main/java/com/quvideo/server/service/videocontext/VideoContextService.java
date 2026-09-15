package com.quvideo.server.service;

import com.quvideo.server.dto.TranscriptSegment;
import com.quvideo.server.dto.VideoContext;
import com.quvideo.server.utils.OcrTextSimilarityUtils;
import com.quvideo.server.utils.OcrUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.TreeMap;

@Service
public class VideoContextService {

    private static final Logger log = LoggerFactory.getLogger(VideoContextService.class);
    private static final long SEGMENT_MS = 60_000L;
    private static final long FALLBACK_FRAME_INTERVAL_MS = 30_000L;
    private static final double DUPLICATE_TEXT_RATIO = 0.15;

    private final SegmentedTranscriptionService transcriptionService;
    private final OcrUtils ocrUtils;

    public VideoContextService(SegmentedTranscriptionService transcriptionService,
                               OcrUtils ocrUtils) {
        this.transcriptionService = transcriptionService;
        this.ocrUtils = ocrUtils;
    }

    /**
     * 把一路视频的语音与画面文字合并成带时间轴的上下文。
     *
     * @param videoPath 本地视频路径
     * @param traceId   链路标识，仅用于日志关联
     */
    public VideoContext build(String videoPath, String traceId) throws Exception {
        List<TranscriptSegment> transcripts = transcriptionService.transcribe(videoPath, traceId);
        List<FramePart> frames = extractFrames(videoPath);
        log.info("video_context_built traceId={} transcripts={} frames={}",
                traceId, transcripts.size(), frames.size());
        return new VideoContext(videoPath, merge(transcripts, frames));
    }

    private List<FramePart> extractFrames(String videoPath) throws Exception {
        Path frameDir = Files.createTempDirectory("quvideo-frames-");
        List<Long> timestamps = new ArrayList<>();
        runCommand(List.of(
                "ffmpeg", "-y", "-i", videoPath,
                "-vf", "fps=1/30,showinfo",
                frameDir.resolve("frame_%06d.jpg").toString()
        ), timestamps);

        List<Path> frameFiles;
        try (var paths = Files.list(frameDir)) {
            frameFiles = paths.filter(Files::isRegularFile).sorted().toList();
        }

        List<FramePart> result = new ArrayList<>();
        String previousText = null;
        for (int i = 0; i < frameFiles.size(); i++) {
            String ocrText;
            try {
                ocrText = ocrUtils.recognize(frameFiles.get(i).toFile());
            } catch (RuntimeException e) {
                log.warn("ocr_frame_failed frame={} trace=skip", frameFiles.get(i).getFileName(), e);
                continue;
            }
            long timestampMs = i < timestamps.size() ? timestamps.get(i) : i * FALLBACK_FRAME_INTERVAL_MS;
            if (OcrTextSimilarityUtils.isNearDuplicate(previousText, ocrText, DUPLICATE_TEXT_RATIO)) {
                continue;
            }
            previousText = ocrText;
            if (!ocrText.isBlank()) {
                result.add(new FramePart(timestampMs, ocrText));
            }
        }
        return result;
    }

    private List<VideoContext.VideoSegment> merge(List<TranscriptSegment> transcripts, List<FramePart> frames) {
        Map<Long, SegmentBuilder> windows = new TreeMap<>();
        for (TranscriptSegment transcript : transcripts) {
            long windowStart = windowStart(transcript.startMs());
            windows.computeIfAbsent(windowStart, SegmentBuilder::new).transcripts.add(transcript.text());
        }
        for (FramePart frame : frames) {
            long windowStart = windowStart(frame.timestampMs());
            windows.computeIfAbsent(windowStart, SegmentBuilder::new).ocrTexts.add(frame.ocrText());
        }
        return windows.values().stream().map(SegmentBuilder::build).toList();
    }

    private long windowStart(long timestampMs) {
        return timestampMs / SEGMENT_MS * SEGMENT_MS;
    }

    private void runCommand(List<String> command, List<Long> timestamps) throws Exception {
        Process process = new ProcessBuilder(command)
                .redirectErrorStream(true)
                .redirectOutput(ProcessBuilder.Redirect.DISCARD)
                .start();
        if (!process.waitFor(15, java.util.concurrent.TimeUnit.MINUTES)) {
            process.destroyForcibly();
            throw new IllegalStateException("FFmpeg 执行超时");
        }
        if (process.exitValue() != 0) {
            throw new IllegalStateException("FFmpeg 退出码 " + process.exitValue());
        }
    }

    private record FramePart(long timestampMs, String ocrText) {
    }

    private static final class SegmentBuilder {
        private final long windowStart;
        private final List<String> transcripts = new ArrayList<>();
        private final List<String> ocrTexts = new ArrayList<>();

        private SegmentBuilder(long windowStart) {
            this.windowStart = windowStart;
        }

        private VideoContext.VideoSegment build() {
            return new VideoContext.VideoSegment(
                    windowStart, windowStart + SEGMENT_MS,
                    String.join(" ", transcripts), String.join(" ", ocrTexts), List.of());
        }
    }
}