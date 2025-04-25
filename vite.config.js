import glsl from 'vite-plugin-glsl'
// import glslify from 'vite-plugin-glslify'
import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import tailwindcss from '@tailwindcss/vite'

// https://vite.dev/config/
export default defineConfig({
    plugins: [
        vue(),
        tailwindcss(),
        glsl({
            include: ['**/*.glsl'],
            // exclude: undefined,
            warnDuplicatedImports: true, // Warn if the same chunk was imported multiple times
            removeDuplicatedImports: true,
            watch: true,
            minify: false
            // root: '/'
        })
        // glslify()
    ]
})
