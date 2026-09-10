package com.quvideo.server.dto;

import com.quvideo.server.entity.MediaFile;

import java.time.LocalDateTime;

public record MediaSummary(
        Long id,
        String filename,
        String status,
        String coverUrl,
        LocalDateTime uploadTime
) {
    public static MediaSummary from(MediaFile mediaFile) {
        return new MediaSummary(
                mediaFile.getId(),
                mediaFile.getFilename(),
                mediaFile.getStatus(),
                mediaFile.getCoverUrl(),
                mediaFile.getUploadTime());
    }
}
