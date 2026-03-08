# Keep MediaPipe internal classes from being stripped
-keep class com.google.mediapipe.** { *; }
-keep class com.google.protobuf.** { *; }

# Optional: If you are using TensorFlow Lite alongside it
-keep class org.tensorflow.lite.** { *; }