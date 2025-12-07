import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:plant_guardian/widgets/auth_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // We also need FirebaseAuth to get the user ID

class RegisterScreen extends StatefulWidget {
  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  String _email = '';
  String _password = '';
  // 🚨 NEW VARIABLE: For the display name input
  String _displayName = '';
  bool _isLoading = false;

  // 🚨 NEW FUNCTION: To handle the registration and data saving
  Future<void> _submitRegistration(AuthService authService) async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      setState(() {
        _isLoading = true;
      });

      try {
        // 1. Register the user with Firebase Auth
        // Register the user (AuthService may not return the user object)
        await authService.registerWithEmailAndPassword(_email, _password);

        // Retrieve the newly created Firebase user
        final User? user = FirebaseAuth.instance.currentUser;

        if (user != null) {
          // 2. Set the display name on the Firebase Auth user object
          await user.updateDisplayName(_displayName);

          // 3. Save initial user data to Firestore
          await FirebaseFirestore.instance.collection("users").doc(user.uid).set({
            "email": user.email,
            "displayName": _displayName, // Save the input name
            "photoUrl": user
                .photoURL, // This is null initially but good practice to include
            "bio": "",
            "favPlant": "",
            "createdAt": FieldValue.serverTimestamp(),
          });

          // 4. Navigate to the next screen upon success
          Navigator.pushReplacementNamed(context, '/');
        }
      } on FirebaseAuthException catch (e) {
        String message;
        if (e.code == 'weak-password') {
          message = 'The password provided is too weak.';
        } else if (e.code == 'email-already-in-use') {
          message = 'An account already exists for that email.';
        } else {
          message = 'Registration failed: ${e.message}';
        }

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Register')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // 🚨 NEW FIELD: Display Name
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a display name';
                  }
                  return null;
                },
                onSaved: (value) => _displayName = value!,
              ),
              const SizedBox(height: 10),
              // Email
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an email';
                  }
                  return null;
                },
                onSaved: (value) => _email = value!,
              ),
              const SizedBox(height: 10),
              // Password
              TextFormField(
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
                onSaved: (value) => _password = value!,
              ),
              const SizedBox(height: 20),
              // Register Button
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _isLoading
                          ? null
                          : () => _submitRegistration(authService),
                      child: const Text('Register'),
                    ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/login');
                },
                child: const Text('Already have an account? Login here'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
