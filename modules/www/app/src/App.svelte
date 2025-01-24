<script lang="ts">
    import { writable, type Writable } from "svelte/store";
    import User from './lib/User.svelte';
    const appName: string = import.meta.env.VITE_APP_NAME
    const currentView: Writable<string> = writable("home")

    function navigate(view: string): void {
        currentView.set(view)
    }
</script>

<div class="header">
  <h3>{appName}</h3>
  <User />
</div>

<div class="navbar">
  <button on:click={() => navigate('home')}>Home</button>
  <button on:click={() => navigate('other')}>Other</button>
</div>

<div class="content">
  {#if $currentView === "home"}
    <p>Welcome to the dashboard!</p>
  {:else if $currentView === "other"}
    <p>Welcome to another page.</p>
  {:else}
    <p>Page not found!</p>
  {/if}
</div>

<style>
  * {
    box-sizing: border-box;
  }

  /* Header Styles */
  .header {
    position: fixed;
    top: 0;
    left: 0;
    width: 100%;
    height: 72px;
    background-color: #213547;
    color: white;
    padding: 0.25rem 1.25rem;
    z-index: 1000;
    display: flex;
    justify-content: space-between;
    align-items: center;
  }

  /* Navbar Styles */
  .navbar {
    position: fixed;
    top: 72px; /* Matches the header height */
    left: 0;
    width: 100%;
    background-color: #213547;
    padding: 0.5rem 1rem;
    text-align: left;
    z-index: 999;
    box-shadow: 0 2px 5px rgba(0, 0, 0, 0.1);
  }

  button {
    margin: 0;
    padding: 0.5rem 1rem;
    font-size: 1rem;
    color: #fff;
    background-color: #213547;
    border: none;
    border-radius: 5px;
    cursor: pointer;
  }

  button:hover {
    background-color: #0056b3;
  }

  /* Content Styles */
  .content {
    margin-top: 120px; /* Offset for the header + navbar height */
    padding: 1rem;
    display: flex;
    flex-direction: column; /* Ensures content stacks vertically */
    align-items: flex-start; /* Align items to the left */
    justify-content: flex-start; /* Align items to the top */
    min-height: calc(100vh - 120px); /* Ensure content spans the full viewport minus header/navbar */
  }

  p {
    margin: 0;
    padding: 0.5rem 0;
    font-family: Arial, sans-serif;
    color: #333;
  }
</style>
