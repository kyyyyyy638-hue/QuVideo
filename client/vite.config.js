import { defineConfig, loadEnv } from 'vite'
import vue from '@vitejs/plugin-vue'

export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, '..', '')
  const backend = env.VITE_DEV_PROXY_TARGET || 'http://localhost:9090'
  return {
    envDir: '..',
    plugins: [vue()],
    server: {
      // 本地补丁：默认端口 5173 在本机不可用 —— Windows 的保留端口区间
      // 5141-5240（Hyper-V/WSL 预留）覆盖了它，绑定会报 EACCES(10013)，
      // 且 5173 还落在被改窄过的动态端口区间 1024-15000 内。
      // 15173 已实测 IPv4/IPv6 双栈均可绑定，且完全避开上述两个区间。
      port: 15173,
      proxy: Object.fromEntries(
        ['/user', '/media', '/analysis', '/admin', '/health'].map(path => [
          path,
          { target: backend, changeOrigin: true }
        ])
      )
    }
  }
})
