import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
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
  String selectedFood = "Banana";
  double caloriesBurned = 0.0;
  bool trackingEnabled = true;
  final Map<String, double> caloriesPerGram = {
    "Banana": 0.89,
    "Rice (cooked)": 1.3,
    "Chicken breast": 1.65,
  };

  List<Map<String, dynamic>> calorieLog = [];
  String today = DateFormat('yyyy-MM-dd').format(DateTime.now());

  double get dailyCalories => calorieLog.fold(0.0, (total, entry) {
    if (entry['date'] == today) {
      return total + (entry['calories'] ?? 0) - (entry['burned'] ?? 0);
    }
    return total;
  });

  double get calculatedCalories =>
      weight * (caloriesPerGram[selectedFood] ?? 0.0);

  @override
  void initState() {
    super.initState();
    loadLog();
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

  void logEntry({bool manual = false}) {
    if (!trackingEnabled) return;
    final now = DateTime.now();
    calorieLog.add({
      "date": DateFormat('yyyy-MM-dd').format(now),
      "time": DateFormat('HH:mm:ss').format(now),
      "food": selectedFood,
      "weight": manual ? 0.0 : weight,
      "calories": manual ? weight : calculatedCalories,
      "burned": caloriesBurned,
    });
    caloriesBurned = 0.0;
    saveLog();
    setState(() {});
  }

  void editEntry(int index) {
    final controller = TextEditingController(
      text: calorieLog[index]['calories'].toString(),
    );
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text("Edit Calories"),
            content: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Calories"),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  final updated = double.tryParse(controller.text);
                  if (updated != null) {
                    setState(() {
                      calorieLog[index]['calories'] = updated;
                      saveLog();
                    });
                  }
                  Navigator.pop(context);
                },
                child: const Text("Save"),
              ),
            ],
          ),
    );
  }

  void showManualCalorieInput() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text("Add Calories Manually"),
            content: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Calories"),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  final input = double.tryParse(controller.text);
                  if (input != null) {
                    setState(() => weight = input);
                    logEntry(manual: true);
                  }
                  Navigator.pop(context);
                },
                child: const Text("Add"),
              ),
            ],
          ),
    );
  }

  void showBurnedInput() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text("Add Burned Calories"),
            content: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Calories burned"),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  final input = double.tryParse(controller.text);
                  if (input != null) {
                    setState(() => caloriesBurned = input);
                    logEntry();
                  }
                  Navigator.pop(context);
                },
                child: const Text("Add"),
              ),
            ],
          ),
    );
  }

  Future<void> fetchWeightFromPico() async {
    const picoUrl = 'http://<PICO_IP_ADDRESS>:5000/weight';
    try {
      final response = await http.get(Uri.parse(picoUrl));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          weight = data['weight'] ?? 0.0;
        });
        logEntry();
      } else {
        print('Failed to fetch weight. Status: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching weight: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Smart Food Scale')),
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
            const Spacer(),
            Center(
              child: ElevatedButton(
                onPressed: fetchWeightFromPico,
                child: const Text('Fetch Weight from Scale'),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: showBurnedInput,
                  child: const Text("Add Burned Calories"),
                ),
                TextButton(
                  onPressed: showManualCalorieInput,
                  child: const Text("Add Calories Manually"),
                ),
              ],
            ),
            const SizedBox(height: 10),
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
                    trailing: IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => editEntry(i),
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
