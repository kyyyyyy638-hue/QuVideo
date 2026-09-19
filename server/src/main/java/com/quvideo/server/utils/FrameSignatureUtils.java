package com.quvideo.server.utils;

import javax.imageio.ImageIO;
import java.awt.Graphics2D;
import java.awt.image.BufferedImage;
import java.io.File;
import java.io.IOException;

/**
 * 关键帧签名工具：把画面缩为 8x8 灰度并按行比较相邻像素得到差分哈希，
 * 用汉明距离判定相邻帧是否属于同一画面。
 *
 * <p>判重放在像素层而不是 OCR 文本层：同一块板书逐行累加时画面连续但文本差异大，
 * 画面已切换而成段字幕延续时文本相近但画面已变，两种情况都会让文本比对失效。
 */
public final class FrameSignatureUtils {

    /** 默认判重阈值：汉明距离不大于该值视为同一画面。 */
    public static final int DEFAULT_DUPLICATE_THRESHOLD = 5;

    private FrameSignatureUtils() {
    }

    /**
     * 计算图像差分哈希。
     *
     * @param imageFile 待计算的图像文件
     * @return 差分哈希；图像无法解码时返回 0
     * @throws IOException 读取文件失败
     */
    public static long signature(File imageFile) throws IOException {
        BufferedImage source = ImageIO.read(imageFile);
        if (source == null) {
            return 0L;
        }
        BufferedImage scaled = new BufferedImage(9, 8, BufferedImage.TYPE_BYTE_GRAY);
        Graphics2D graphics = scaled.createGraphics();
        try {
            graphics.drawImage(source, 0, 0, 9, 8, null);
        } finally {
            graphics.dispose();
        }

        long hash = 0L;
        for (int y = 0; y < 8; y++) {
            for (int x = 0; x < 8; x++) {
                hash <<= 1;
                if (scaled.getRGB(x, y) > scaled.getRGB(x + 1, y)) {
                    hash |= 1L;
                }
            }
        }
        return hash;
    }

    /**
     * 两个签名是否近似重复。
     *
     * @param previous  上一帧签名
     * @param current   当前帧签名
     * @param threshold 允许的最大汉明距离
     */
    public static boolean isNearDuplicate(long previous, long current, int threshold) {
        return Long.bitCount(previous ^ current) <= threshold;
    }
}
