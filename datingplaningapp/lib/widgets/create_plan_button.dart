import 'package:datingplaningapp/modules/plan/create_plan.dart';
import 'package:flutter/material.dart';

class CreatePlanButton extends StatefulWidget {
  const CreatePlanButton({super.key});

  @override
  State<CreatePlanButton> createState() => _CreatePlanButtonState();
}

class _CreatePlanButtonState extends State<CreatePlanButton> {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0),
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {
          // Navigate to CreatePlan screen
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreatePlan()),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.pink,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
        ),
        child: const Text(
          'Create New Plan',
          style: TextStyle(fontSize: 16, color: Colors.white),
        ),
      ),
    );
  }
}
