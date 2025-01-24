import { mount } from 'svelte'
import './app.css'
import App from './App.svelte'

document.title = import.meta.env.VITE_APP_NAME || 'Default App Name';

const app = mount(App, {
  target: document.getElementById('app')!,
})

export default app
