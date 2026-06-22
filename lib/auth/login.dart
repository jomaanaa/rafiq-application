import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'role_selection_page.dart';
import 'provider_navigation.dart';
import 'package:rafiq/auth/patient_navigation_wrapper.dart';
import 'session_manager.dart';
import 'package:rafiq/auth/api_service.dart';
import 'package:rafiq/auth/provider_navigation.dart';
import '../admin/admin_shell.dart'; 
import 'pending_page.dart';

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();

}

class _LoginState extends State<Login> {

  final TextEditingController emailController =
      TextEditingController();

  final TextEditingController passwordController =
      TextEditingController();

  final GlobalKey<FormState> formKey =
      GlobalKey<FormState>();

  final Color navyColor =
      const Color(0xFF2B2C41);

  bool isLoading = false;

  @override
  void dispose() {

    emailController.dispose();

    passwordController.dispose();

    super.dispose();

  }

  @override
  Widget build(BuildContext context) {

    return GestureDetector(

      onTap: () =>
          FocusScope.of(context).unfocus(),

      child: Scaffold(

        backgroundColor: Colors.white,

        body: Center(

          child: SingleChildScrollView(

            padding:
                const EdgeInsets.symmetric(
              horizontal: 30,
            ),

            child: Form(

              key: formKey,

              child: Column(

                mainAxisSize: MainAxisSize.min,

                children: [

                  Image.asset(
                    'assets/images/logo.png',
                    height: 70,
                  ),

                  const SizedBox(height: 10),

                  Text(

                    "Welcome back!",

                    style: TextStyle(
                      fontSize: 26,
                      fontWeight:
                          FontWeight.bold,
                      color: navyColor,
                    ),

                  ),

                  const SizedBox(height: 25),

                  /// EMAIL
                  TextFormField(

                    controller:
                        emailController,

                    keyboardType:
                        TextInputType
                            .emailAddress,

                decoration: InputDecoration(
                  labelText: "Email",
                  prefixIcon: const Icon(Icons.email),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide(color: navyColor, width: 2),
                  ),
                  floatingLabelStyle: TextStyle(color: navyColor),
                ),

                    validator: (value) {

                      if (value ==
                              null ||
                          value.isEmpty) {

                        return "Email can't be empty";

                      }

                      return null;

                    },

                  ),

                  const SizedBox(height: 16),

                  /// PASSWORD
                  TextFormField(

                    controller:
                        passwordController,

                    obscureText: true,

                  decoration: InputDecoration(
                    labelText: "Password",
                    prefixIcon: const Icon(Icons.lock),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide(color: navyColor, width: 2),
                    ),
                    floatingLabelStyle: TextStyle(color: navyColor),
                  ),

                    validator: (value) {

                      if (value ==
                              null ||
                          value.isEmpty) {

                        return "Password can't be empty";

                      }

                      return null;

                    },

                  ),

                  const SizedBox(height: 25),

                  /// LOGIN BUTTON
                  SizedBox(

                    width: double.infinity,

                    child: ElevatedButton(

                      style:
                          ElevatedButton
                              .styleFrom(

                        backgroundColor:
                            navyColor,

                        shape:
                            RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius
                                  .circular(
                            15,
                          ),
                        ),

                        padding:
                            const EdgeInsets
                                .symmetric(
                          vertical: 15,
                        ),

                      ),

                      onPressed:
                          isLoading
                              ? null
                              : _handleLogin,

                      child: isLoading

                          ? const CircularProgressIndicator(
                              color:
                                  Colors
                                      .white,
                            )

                          : const Text(

                              "Sign in",

                              style:
                                  TextStyle(
                                color: Colors
                                    .white,
                              ),

                            ),

                    ),

                  ),

                  const SizedBox(height: 15),

                  /// SIGN UP
                  Row(

                    mainAxisAlignment:
                        MainAxisAlignment
                            .center,

                    children: [

                      const Text(
                        "Don't have an account? ",
                      ),

                      GestureDetector(

                        onTap: () {

                          Navigator.push(

                            context,

                            MaterialPageRoute(

                              builder:
                                  (_) =>
                                      const RoleSelectionPage(),

                            ),

                          );

                        },

                        child: const Text(

                          "Sign Up",

                          style: TextStyle(
                            fontWeight:
                                FontWeight
                                    .bold,
                            decoration:
                                TextDecoration
                                    .underline,
                          ),

                        ),

                      ),

                    ],

                  ),

                ],

              ),

            ),

          ),

        ),

      ),

    );

  }

  /// LOGIN FUNCTION
  Future<void> _handleLogin() async {

    if (!formKey.currentState!
        .validate()) {

      return;

    }

    setState(() => isLoading = true);

    try {

      final response = await http.post(

        Uri.parse(
          'http://10.13.114.211/Api/login.php',
        ),

        headers: {

          'Content-Type':
              'application/json'

        },

        body: jsonEncode({

          'email': emailController.text
              .trim(),

          'password':
              passwordController.text
                  .trim(),

        }),

      );

      final data =
          jsonDecode(response.body);

      if (response.statusCode ==
              200 &&
          data['success'] == true) {

        /// SAVE SESSION
        await SessionManager.logout();

        await SessionManager
            .saveUser(data);

        String role = data['role'];

        String firstName =
            data['firstName'] ??
                "User";




        /// =========================
        /// PATIENT
        /// =========================
        if (role == "patient") {

          Navigator.pushReplacement(

            context,

            MaterialPageRoute(

              builder: (_) =>
                  PatientNavigationWrapper(
                firstName:
                    firstName,
              ),

            ),

          );

        }




        /// =========================
        /// PROVIDER
        /// =========================
        else if (role == "provider") {

          int userId = int.parse(data["user_id"].toString());

          // 1️⃣ Get provider type
          final providerType = await ApiService.getProviderType(userId);

          // 2️⃣ Check provider status (pending / accepted / rejected)
          String providerStatus = 'pending';
          try {
            final statusRes = await http.get(
              Uri.parse('http://10.13.114.211/Api/check_status.php?user_id=$userId'),
            );
            final statusData = jsonDecode(statusRes.body);
            if (statusData['success'] == true) {
              providerStatus = (statusData['status'] ?? 'pending').toLowerCase().trim();
            }
          } catch (_) {}

          // 3️⃣ Navigate based on status
          if (providerStatus == 'accepted' && providerType != null) {
            // ✅ Accepted → go to dashboard
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => ProviderNavigation(providerType: providerType),
              ),
            );
          } else {
            // ⏳ Pending or ❌ Rejected → go to pending page
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => PendingPage(
                  userId: userId,
                  providerType: providerType,
                ),
              ),
            );
          }
        }


/// =========================
/// ADMIN
/// =========================
else if (role == "admin") {

  Navigator.pushReplacement(

    context,

    MaterialPageRoute(

      builder: (_) =>
          const AdminShell(),

    ),

  );

}

/// =========================
/// UNKNOWN ROLE
/// =========================
else {

  ScaffoldMessenger.of(
          context)
      .showSnackBar(

    SnackBar(

      content: Text(
        "Role not supported yet: $role",
      ),

    ),

  );

}
      }




      else {

        ScaffoldMessenger.of(
                context)
            .showSnackBar(

          SnackBar(

            content: Text(
              data['message'] ??
                  "Login failed",
            ),

          ),

        );

      }

    } catch (e) {

      ScaffoldMessenger.of(
              context)
          .showSnackBar(

        SnackBar(

          content: Text(
            "Error: $e",
          ),

        ),

      );

    } finally {

      setState(
        () => isLoading = false,
      );

    }

  }

}