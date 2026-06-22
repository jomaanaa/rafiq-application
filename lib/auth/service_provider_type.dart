import 'package:flutter/material.dart';
import 'provider_registration_page.dart';
import 'package:flutter/widgets.dart';

class ProviderTypeSelectionPage extends StatefulWidget {
  const ProviderTypeSelectionPage({super.key});

  @override
  State<ProviderTypeSelectionPage> createState() =>
      _ProviderTypeSelectionPageState();
}

class _ProviderTypeSelectionPageState extends State<ProviderTypeSelectionPage> {
  String? selectedType;
  final Color primaryColor = const Color(0xFF3C3A66);

  @override
  Widget build(BuildContext context) {
    final types = ["Doctor", "Caregiver", "Driver", "Interpreter"];
    final images = [
      'assets/images/doctors.jpeg',
      'assets/images/caregivers.jpeg',
      'assets/images/drivers.jpeg',
      'assets/images/interpreters.jpeg',
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: primaryColor),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Image.asset('assets/images/logo.png', height: 60),
              const SizedBox(height: 12),
              const Text(
                "Support users by offering care, guidance, and assistance.\nWhich describes you best?",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 20),

              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 1,
                  ),
                  itemCount: types.length,
                  itemBuilder: (context, index) {
                    final isSelected = selectedType == types[index];

                    return GestureDetector(
                      onTap: () =>
                          setState(() => selectedType = types[index]),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white, // always white
                          borderRadius: BorderRadius.circular(20),
                          border: isSelected
                              ? Border.all(
                                  color: primaryColor,
                                  width: 2,
                                )
                              : Border.all(
                                  color: Colors.transparent,
                                  width: 2,
                                ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(15),
                              child: Image.asset(
                                images[index],
                                width: 100,
                                height: 100,
                                fit: BoxFit.cover,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              types[index],
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              ElevatedButton(
                onPressed: selectedType == null
                    ? null
                    : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProviderRegistrationPage(
                              providerType: selectedType!,
                            ),
                          ),
                        );
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: const Text(
                  "Continue",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}