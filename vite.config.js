import { sveltekit } from '@sveltejs/kit/vite';

/** @type {import('vite').UserConfig} */
const config = {
    plugins: [sveltekit()],
    optimizeDeps: {
        exclude: ['chart.js']
    },
    server: {
        //Insert port here, TODO: Make it easier for backend to add port
        port: 1000
    }
};

export default config;