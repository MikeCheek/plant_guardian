# 🌿 Plant Guardian

An AI/ML powered plant monitoring and care application designed to bridge the gap between technology and horticulture. Plant Guardian helps you identify species, diagnose diseases, and chat with an intelligent agent to keep your greenery thriving.

> **Note:** This project is currently in early development. Features and functionalities are subject to change.

## 🎨 Why Plant Guardian?

Let’s be honest: plant care is hard. Many of us have lost plants to "questionable" soil choices or simple forgetfulness. This project serves three purposes:

- **Practical Utility:** Helping people keep their plants alive through AI.
- **Skill Building:** Bridging Flutter development with advanced ML pipelines.
- **Artistic Outlet:** Custom plant illustrations drawn specifically for this UI!

## 🚀 The Ecosystem

The Plant Guardian project consists of several specialized components:

- [Plant Agent Backend](https://github.com/MikeCheek/plant-agent): AI agent logic using Hugging Face's smolagents
- [Plant DB Bot](https://github.com/MikeCheek/plant-db-bot): Telegram bot for database expansion and management
- [Species Classifier Notebook](https://www.kaggle.com/code/michelepulvirenti/house-plant-recognition-using-efficientnetv2b0): ML model training for species identification
- [Disease Classifier Notebook](https://www.kaggle.com/code/michelepulvirenti/house-plant-disease-recognition): ML model training for disease detection and severity assessment

## ✨ Features

- [x] Smart Identification: Live camera predictions using TensorFlow Lite
- [x] Disease Diagnosis: Real-time health detection and severity analysis
- [x] GuardAI Agent: Intelligent chatbot with web access and planning tools
- [x] Garden Management: Track metadata for your personal plant collection
- [x] User Authentication: Secure accounts and data syncing
- [x] Adaptive UI: Light/dark mode with custom illustrations
- [ ] Smart Reminders: Watering and fertilizing notifications (In Progress)
- [ ] Eco-Helper: Waste identification and recycling guide (Planned)

## 📊 Model Performance

| Species Classifier | Accuracy | Loss |
| -----------------: | -------: | ---: |
|           Training |      94% |  20% |
|         Validation |      92% |  37% |

| Disease Classifier | Accuracy | Loss |
| -----------------: | -------: | ---: |
|           Training |      98% |   6% |
|         Validation |      92% |  25% |

## 📸 Gallery

**Live Camera Predictions:**

<div style="display:flex; gap:1rem; align-items:flex-start; flex-wrap:wrap;">
  <figure style="display:flex; flex-direction:column; align-items:center; margin:0;">
    <img src="screenshots/poinsettia.jpg" alt="Poinsettia" style="width:160px; height:auto; border-radius:6px;">
  </figure>
  <figure style="display:flex; flex-direction:column; align-items:center; margin:0;">
    <img src="screenshots/sanseviera.jpg" alt="Sansevieria" style="width:160px; height:auto; border-radius:6px;">
  </figure>
  <figure style="display:flex; flex-direction:column; align-items:center; margin:0;">
    <img src="screenshots/schefflera.jpg" alt="Schefflera" style="width:160px; height:auto; border-radius:6px;">
  </figure>
  <figure style="display:flex; flex-direction:column; align-items:center; margin:0;">
    <img src="screenshots/aloevera.jpg" alt="Aloe Vera" style="width:160px; height:auto; border-radius:6px;">
  </figure>
</div>

**GuardAI Agent & Garden Management:**

<div style="display:flex; gap:1rem; align-items:flex-start; flex-wrap:wrap;">
  <figure style="display:flex; flex-direction:column; align-items:center; margin:0;">
    <img src="screenshots/agentthinking.jpg" alt="GuardAI" style="width:160px; height:auto; border-radius:6px;">
  </figure>
  <figure style="display:flex; flex-direction:column; align-items:center; margin:0;">
    <img src="screenshots/gardens.jpg" alt="My Gardens" style="width:160px; height:auto; border-radius:6px;">
  </figure>
  <figure style="display:flex; flex-direction:column; align-items:center; margin:0;">
    <img src="screenshots/garden.jpg" alt="Garden Details" style="width:160px; height:auto; border-radius:6px;">
  </figure>
</div>

## 🛠️ Running the App

```bash
flutter run --dart-define-from-file=config.json
```

```bash
flutter build apk --dart-define-from-file=config.json
```
