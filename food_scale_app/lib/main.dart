import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

void main() {
  runApp(const FoodScaleApp());
}

class FoodScaleApp extends StatelessWidget {
  const FoodScaleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Food Scale',
      theme: ThemeData(primarySwatch: Colors.green),
      home: const WeightScreen(),
    );
  }
}

class WeightScreen extends StatefulWidget {
  const WeightScreen({super.key});

  @override
  State<WeightScreen> createState() => _WeightScreenState();
}

class _WeightScreenState extends State<WeightScreen> {
  double weight = 0.0;
  String selectedFood = "Banana";
  double caloriesBurned = 0.0;
  double goalCalories = 2000.0;
  bool trackingEnabled = true;
  final Map<String, double> caloriesPerGram = {
    "Banana": 0.89,
    "Rice (cooked)": 1.3,
    "Chicken breast": 1.65,
    "Apple": 0.52,
    "Egg (boiled)": 1.55,
    "Oatmeal": 0.68,
    "Salmon": 2.08,
    "Beef (lean)": 2.5,
    "Tofu": 0.76,
    "Almonds": 5.76,
    "Peanut Butter": 5.88,
    "Whole Milk": 0.61,
    "Cheddar Cheese": 4.02,
    "Pasta (cooked)": 1.31,
    "Bread (white)": 2.65,
    "Broccoli": 0.34,
    "Carrots": 0.41,
    "Avocado": 1.6,
    "Granola Bar": 4.7,
    "Yogurt (plain)": 0.59,
  };

  List<Map<String, dynamic>> calorieLog = [];
  String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
  Timer? updateTimer;

  double get dailyCalories => calorieLog.fold(0.0, (total, entry) {
    if (entry['date'] == today) {
      return total + (entry['calories'] ?? 0) - (entry['burned'] ?? 0);
    }
    return total;
  });

  double get caloriesLeft => goalCalories - dailyCalories;
  double get calculatedCalories =>
      weight * (caloriesPerGram[selectedFood] ?? 0.0);

  @override
  void initState() {
    super.initState();
    loadLog();
    updateTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => fetchWeightFromPico(),
    );
  }

  @override
  void dispose() {
    updateTimer?.cancel();
    super.dispose();
  }

  Future<void> loadLog() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString('calorieLog');
    if (stored != null) {
      final decoded = List<Map<String, dynamic>>.from(json.decode(stored));
      setState(() => calorieLog = decoded);
    }
  }

  Future<void> saveLog() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('calorieLog', json.encode(calorieLog));
  }

  void logEntryFromSensor() {
    if (!trackingEnabled) return;
    final now = DateTime.now();
    calorieLog.add({
      "date": DateFormat('yyyy-MM-dd').format(now),
      "time": DateFormat('HH:mm:ss').format(now),
      "food": selectedFood,
      "weight": weight,
      "calories": calculatedCalories,
      "burned": caloriesBurned,
    });
    caloriesBurned = 0.0;
    saveLog();
    setState(() {});
  }

  void handleTouchInput(Map<String, dynamic> data) {
    final bool zero = data['touch1'] ?? false;
    final bool reset = data['touch2'] ?? false;
    final bool log = data['touch3'] ?? false;

    if (zero) {
      print("Tare requested");
    } else if (reset) {
      print("Reset tare requested");
    } else if (log) {
      logEntryFromSensor();
    }
  }

  Future<void> fetchWeightFromPico() async {
    const picoUrl = 'http://172.20.10.4:5000/weight';
    try {
      final response = await http.get(Uri.parse(picoUrl));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final newWeight = data['weight'] ?? 0.0;
        setState(() {
          weight = newWeight;
        });
        handleTouchInput(data);
      }
    } catch (e) {
      print('Error fetching weight: $e');
    }
  }

  void showManualInputDialog({
    required String title,
    required Function(double) onSubmitted,
  }) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: Text(title),
            content: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Enter value in kcal",
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  final value = double.tryParse(controller.text);
                  if (value != null) {
                    onSubmitted(value);
                  }
                  Navigator.pop(context);
                },
                child: const Text("Submit"),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Food Scale'),
        actions: [
          IconButton(
            icon: const Icon(Icons.local_fire_department),
            tooltip: 'Add Burned Calories',
            onPressed:
                () => showManualInputDialog(
                  title: 'Burned Calories',
                  onSubmitted: (value) {
                    setState(() => caloriesBurned = value);
                  },
                ),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Manual Calories',
            onPressed:
                () => showManualInputDialog(
                  title: 'Add Calories (Manual)',
                  onSubmitted: (value) {
                    final now = DateTime.now();
                    calorieLog.add({
                      "date": DateFormat('yyyy-MM-dd').format(now),
                      "time": DateFormat('HH:mm:ss').format(now),
                      "food": "Manual Entry",
                      "weight": 0.0,
                      "calories": value,
                      "burned": 0.0,
                    });
                    saveLog();
                    setState(() {});
                  },
                ),
          ),
          IconButton(
            icon: const Icon(Icons.flag),
            tooltip: 'Set Goal Calories',
            onPressed:
                () => showManualInputDialog(
                  title: 'Set Daily Goal',
                  onSubmitted: (value) => setState(() => goalCalories = value),
                ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              title: const Text("Track Calories"),
              value: trackingEnabled,
              onChanged: (val) => setState(() => trackingEnabled = val),
            ),
            const SizedBox(height: 10),
            Text(
              'Weight: ${weight.toStringAsFixed(2)} g',
              style: const TextStyle(fontSize: 24),
            ),
            const SizedBox(height: 20),
            DropdownButton<String>(
              value: selectedFood,
              items:
                  caloriesPerGram.keys.map((food) {
                    return DropdownMenuItem(value: food, child: Text(food));
                  }).toList(),
              onChanged: (value) => setState(() => selectedFood = value!),
            ),
            const SizedBox(height: 20),
            Text(
              'Calories: ${calculatedCalories.toStringAsFixed(2)} kcal',
              style: const TextStyle(fontSize: 20),
            ),
            const SizedBox(height: 10),
            Text(
              'Burned: ${caloriesBurned.toStringAsFixed(2)} kcal',
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 10),
            Text(
              'Net Calories Today: ${dailyCalories.toStringAsFixed(2)} kcal',
              style: const TextStyle(fontSize: 18),
            ),
            Text(
              'Goal: ${goalCalories.toStringAsFixed(0)} kcal',
              style: const TextStyle(fontSize: 18),
            ),
            Text(
              'Remaining: ${caloriesLeft.toStringAsFixed(0)} kcal',
              style: const TextStyle(fontSize: 18, color: Colors.blue),
            ),
            const SizedBox(height: 20),
            const Text("Daily Log:", style: TextStyle(fontSize: 18)),
            Expanded(
              child: ListView.builder(
                itemCount: calorieLog.length,
                itemBuilder: (_, i) {
                  final entry = calorieLog[i];
                  if (entry['date'] != today) return const SizedBox.shrink();
                  return ListTile(
                    title: Text(
                      "${entry['food']} - ${entry['weight']}g - ${entry['calories'].toStringAsFixed(1)} kcal",
                    ),
                    subtitle: Text(
                      "${entry['time']} | Burned: ${entry['burned']} kcal",
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
