import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  double? frozenWeight;
  bool scaleOn = true;
  Timer? updateTimer;
  String selectedFood = "Banana";

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

  @override
  void initState() {
    super.initState();
    loadLog();
    fetchWeightFromPico();
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

  void logFrozenWeight(double value) {
    final now = DateTime.now();
    final calories = value * (caloriesPerGram[selectedFood] ?? 0.0);
    calorieLog.add({
      "date": DateFormat('yyyy-MM-dd').format(now),
      "time": DateFormat('HH:mm:ss').format(now),
      "weight": value,
      "food": selectedFood,
      "calories": calories,
    });
    saveLog();
    setState(() {});
  }

  double get dailyCalories => calorieLog.fold(0.0, (total, entry) {
    if (entry['date'] == today) {
      return total + (entry['calories'] ?? 0);
    }
    return total;
  });

  Future<void> fetchWeightFromPico() async {
    const url =
        'http://192.168.1.78:5000/weight'; // Replace with your Pico's IP
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        final newFrozen = data['frozen_weight'];
        final newWeight = (data['weight'] ?? 0.0).toDouble();

        // Use local frozenWeight reference to compare before updating
        final wasFrozen = frozenWeight != null;
        final isNowFrozen = newFrozen != null;

        setState(() {
          scaleOn = data['scale_on'] ?? true;

          if (isNowFrozen) {
            final frozenVal = (newFrozen as num).toDouble();

            // Only log the first time it freezes
            if (!wasFrozen) {
              frozenWeight = frozenVal;
              logFrozenWeight(frozenWeight!);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    "📋 Weight frozen and logged: ${frozenWeight!.toStringAsFixed(2)} g",
                  ),
                ),
              );
            }
            // Do not update live weight while frozen
          } else {
            if (wasFrozen) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("🔄 Unfrozen — now showing live weight"),
                ),
              );
            }
            frozenWeight = null;
            weight = newWeight;
          }
        });
      }
    } catch (e) {
      print('❌ Error fetching from Pico: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayWeight = frozenWeight ?? weight;
    final label = frozenWeight != null ? "FROZEN" : "Weight";
    final calculatedCalories =
        displayWeight * (caloriesPerGram[selectedFood] ?? 0.0);

    return Scaffold(
      appBar: AppBar(title: const Text("Smart Food Scale")),
      body: AnimatedOpacity(
        opacity: scaleOn ? 1.0 : 0.3,
        duration: const Duration(milliseconds: 500),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "$label: ${displayWeight.toStringAsFixed(2)} g",
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: frozenWeight != null ? Colors.orange : Colors.black,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                scaleOn ? "Scale ON" : "Scale OFF",
                style: TextStyle(
                  color: scaleOn ? Colors.green : Colors.red,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Text("Food: "),
                  Expanded(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: selectedFood,
                      items:
                          caloriesPerGram.keys.map((food) {
                            return DropdownMenuItem(
                              value: food,
                              child: Text(food),
                            );
                          }).toList(),
                      onChanged:
                          (value) => setState(() => selectedFood = value!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text("Calories: ${calculatedCalories.toStringAsFixed(2)} kcal"),
              Text("Total Today: ${dailyCalories.toStringAsFixed(2)} kcal"),
              const SizedBox(height: 20),
              const Divider(),
              const Text(
                "Recent Logs",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              for (var entry in calorieLog.reversed.take(5))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    "${entry['date']} ${entry['time']} — ${entry['food']} — ${entry['weight']}g = ${entry['calories'].toStringAsFixed(1)} kcal",
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
