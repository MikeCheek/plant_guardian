# Plant Guardian

An AI/ML powered plant monitoring and care application built with Flutter.

_Disclaimer: This project is currently in its early stages of development. Features and functionalities are subject to change._

## Features

- [x] Theme mode (light/dark)
- [x] ML plant classifier (TensorFlow Lite model)
- [x] Live camera classifier (real-time predictions)
- [x] AI agent chatbot (GuardAI)
- [ ] User authentication (accounts, secure sign-in)
- [ ] ML plant disease classifier (detect diseases & severity)
- [ ] Working AI Agent with tools (planner, web/tool access)
- [ ] My Garden management (add/remove plants, metadata)
- [ ] Notification reminders (watering, fertilizing, care tips)
- [ ] Garbage recycling helper (identify & sort waste)

## Screenshots from Early Development

<figure style="display:flex; flex-direction:column; align-items:center; margin:0;">
    <img src="screenshots/welcome.jpg" alt="Welcome screen" style="width:180px; height:auto; border-radius:6px;">
  </figure>

### Live camera predictions

To perform the plant species prediction, the app uses a trained TensorFlow Lite model integrated with the device's camera.

The notebook used to train the model can be found on my kaggle profile [here](https://www.kaggle.com/code/michelepulvirenti/house-plant-recognition-using-efficientnetv2b0).

#### Final Model Performance

|   Metric | Training | Validation |
| -------: | -------: | ---------: |
| Accuracy |   0.9379 |     0.9165 |
|     Loss |   0.1965 |     0.3731 |

Below are some example predictions made by the app:

<div style="display:flex; gap:1rem; align-items:flex-start; flex-wrap:wrap;">
  <figure style="display:flex; flex-direction:column; align-items:center; margin:0;">
    <img src="screenshots/dumbcane.jpg" alt="Ficus elastica prediction" style="width:180px; height:auto; border-radius:6px;">
  </figure>

  <figure style="display:flex; flex-direction:column; align-items:center; margin:0;">
    <img src="screenshots/monsteradeliciosa.jpg" alt="Monstera deliciosa prediction" style="width:180px; height:auto; border-radius:6px;">
  </figure>

  <figure style="display:flex; flex-direction:column; align-items:center; margin:0;">
    <img src="screenshots/orchid.jpg" alt="Orchid prediction" style="width:180px; height:auto; border-radius:6px;">
  </figure>

  <figure style="display:flex; flex-direction:column; align-items:center; margin:0;">
    <img src="screenshots/sanseviera.jpg" alt="Sansevieria prediction" style="width:180px; height:auto; border-radius:6px;">
  </figure>

   <figure style="display:flex; flex-direction:column; align-items:center; margin:0;">
    <img src="screenshots/ficuselastica.jpg" alt="Ficus elastica prediction" style="width:180px; height:auto; border-radius:6px;">
  </figure>
</div>

## GuardAI - AI Agent for Plant Care

<figure style="display:flex; flex-direction:column; align-items:center; margin:0;">
    <img src="screenshots/guardai.jpg" alt="GuardAI prediction" style="width:180px; height:auto; border-radius:6px;">
  </figure>

## Running the App

```bash
flutter run --dart-define-from-file=config.json
```

```bash
flutter build apk --dart-define-from-file=config.json
```
