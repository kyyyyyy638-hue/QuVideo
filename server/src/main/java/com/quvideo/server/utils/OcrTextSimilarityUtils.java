package com.quvideo.server.utils;

/**
 * 相邻帧去重：比较两帧 OCR 文本的编辑距离，足够接近就认为画面没有变化。
 *
 * <p>阈值取相对值：短文本允许的编辑距离小，长文本按比例放宽，
 * 否则板书类长文本会永远被判成「不同帧」。
 */
public final class OcrTextSimilarityUtils {

    private OcrTextSimilarityUtils() {
    }

    /**
     * 编辑距离，只统计插入与删除。
     *
     * @param left  上一帧文本
     * @param right 当前帧文本
     * @return 最小编辑次数
     */
    public static int editDistance(String left, String right) {
        String a = left == null ? "" : left;
        String b = right == null ? "" : right;
        int[] previous = new int[b.length() + 1];
        int[] current = new int[b.length() + 1];
        for (int j = 0; j <= b.length(); j++) {
            previous[j] = j;
        }
        for (int i = 1; i <= a.length(); i++) {
            current[0] = i;
            for (int j = 1; j <= b.length(); j++) {
                int cost = a.charAt(i - 1) == b.charAt(j - 1) ? 0 : 1;
                current[j] = Math.min(Math.min(current[j - 1] + 1, previous[j] + 1), previous[j - 1] + cost);
            }
            int[] swap = previous;
            previous = current;
            current = swap;
        }
        return previous[b.length()];
    }

    /**
     * 两帧文本是否近似重复。
     *
     * @param ratio 允许的编辑距离占较长文本长度的比例
     */
    public static boolean isNearDuplicate(String previousText, String currentText, double ratio) {
        String left = previousText == null ? "" : previousText.trim();
        String right = currentText == null ? "" : currentText.trim();
        int longest = Math.max(left.length(), right.length());
        if (longest == 0) {
            return true;
        }
        return (double) editDistance(left, right) / longest <= ratio;
    }
}