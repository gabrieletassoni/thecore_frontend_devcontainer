#!/bin/bash -e

# Check if a project name has been provided
if [ -z "$1" ]; then
  echo "Error: specify the project name as an argument."
  echo "Usage: $0 <project_name>"
  exit 1
fi

# Check if $1 is valid for vite name: only lowercase letters and hyphens
if [[ ! "$1" =~ ^[a-z-]+$ ]]; then
  echo "Error: the project name can only contain lowercase letters and hyphens."
  exit 1
fi

# Project name passed as an argument
PROJECT_NAME=$1

# Step 1: Create a new Vue.js project with Vite using the Vue template
echo "Creating Vue.js project with Vite..."
npm create vite@latest "$PROJECT_NAME" -- --template vue

# Enter the project directory
# cd $PROJECT_NAME || exit

# Step 2: Install Ionic and Pinia dependencies
echo "Installing Ionic 8, Ionic Router, and Pinia..."
npm install @ionic/vue@^8 @ionic/vue-router@^8 ionicons pinia @vue/cli-service@latest

# Step 3: Add necessary development dependencies
echo "Installing development dependencies..."
npm install @vitejs/plugin-vue --save-dev

# Step 4: Create and modify necessary files

# Modify main.js to include Ionic and Pinia
echo "Modifying src/main.js..."
cat <<EOL > src/main.js
import { createApp } from 'vue';
import App from './App.vue';
import router from './router';
import { IonicVue } from '@ionic/vue';
import { createPinia } from 'pinia';

// Import Ionic core styles
import '@ionic/vue/css/core.css';

// Optional CSS utils
import '@ionic/vue/css/normalize.css';
import '@ionic/vue/css/structure.css';
import '@ionic/vue/css/typography.css';

const app = createApp(App);

app.use(IonicVue);
app.use(createPinia());
app.use(router);

app.mount('#app');
EOL

# Step 5: Configure the router
echo "Modifying src/router/index.js..."
mkdir -p src/router
cat <<EOL > src/router/index.js
import { createRouter, createWebHistory } from 'vue-router';
import HomePage from '../views/HomePage.vue';

const routes = [
  {
    path: '/',
    name: 'Home',
    component: HomePage,
  },
];

const router = createRouter({
  history: createWebHistory(),
  routes,
});

export default router;
EOL

# Step 6: Create a sample view
echo "Creating a sample view HomePage.vue..."
mkdir -p src/views
cat <<EOL > src/views/HomePage.vue
<template>
  <ion-page>
    <ion-header>
      <ion-toolbar>
        <ion-title>Ionic Vue App</ion-title>
      </ion-toolbar>
    </ion-header>
    <ion-content>
      <ion-button @click="logMessage">Click Me</ion-button>
    </ion-content>
  </ion-page>
</template>

<script>
export default {
  name: 'HomePage',
  methods: {
    logMessage() {
      console.log('Hello from Ionic Vue App!');
    },
  },
};
</script>

<style scoped>
ion-toolbar {
  --background: #3880ff;
  --color: white;
}
</style>
EOL

# Step 7: Configure the vite.config.js file
echo "Modifying vite.config.js..."
cat <<EOL > vite.config.js
import { defineConfig } from 'vite';
import vue from '@vitejs/plugin-vue';

export default defineConfig({
  plugins: [vue()],
  server: {
    port: 8100,
  },
});
EOL

# initialize ionic project with the app name
ionic init "$PROJECT_NAME" --type vue-vite --force

# Step 8: Start the project
echo "The project $PROJECT_NAME has been successfully created! Run 'npm run dev' or 'ionic serve' to start the application."
