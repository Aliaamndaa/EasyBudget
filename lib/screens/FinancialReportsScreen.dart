import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:pie_chart/pie_chart.dart' as pc;
import 'package:fl_chart/fl_chart.dart' as fl;

class FinancialReportsScreen extends StatefulWidget {
  final String email;

  const FinancialReportsScreen({Key? key, required this.email}) : super(key: key);

  @override
  State<FinancialReportsScreen> createState() => _FinancialReportsScreenState();
}

class _FinancialReportsScreenState extends State<FinancialReportsScreen> {
  Map<String, double> categoryData = {};
  List<fl.FlSpot> monthlySpots = [];
  int selectedYear = DateTime.now().year;
  int selectedMonth = DateTime.now().month;
  bool isLoading = true;

  List<int> availableYears = List.generate(5, (index) => DateTime.now().year - index);

  @override
  void initState() {
    super.initState();
    fetchExpenseSummary();
    fetchMonthlyTrends();
  }

  Future<void> fetchExpenseSummary() async {
    final url = Uri.parse("http://192.168.0.24/get_expense_summary.php");

    try {
      final response = await http.post(
        url,
        body: {
          'email': widget.email,
          'month': selectedMonth.toString(),
          'year': selectedYear.toString(),
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        Map<String, double> parsedData = {};

        for (var item in data) {
          final String category = item['category'];
          final double total = double.tryParse(item['total'].toString()) ?? 0.0;
          parsedData[category] = total;
        }

        setState(() {
          categoryData = parsedData;
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> fetchMonthlyTrends() async {
    final url = Uri.parse("http://192.168.0.24/get_monthly_summary.php");

    try {
      final response = await http.post(
        url,
        body: {
          'email': widget.email,
          'year': selectedYear.toString(),
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        List<fl.FlSpot> spots = [];

        for (var item in data) {
          int month = int.tryParse(item['month'].toString()) ?? 0;
          double total = double.tryParse(item['total'].toString()) ?? 0.0;
          if (month > 0 && month <= 12) {
            spots.add(fl.FlSpot(month.toDouble(), total));
          }
        }

        setState(() {
          monthlySpots = spots;
        });
      }
    } catch (e) {
      print("Error loading monthly trends: $e");
    }
  }

  final List<String> monthLabels = [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  void _onYearChanged(int newYear) {
    setState(() {
      selectedYear = newYear;
      isLoading = true;
    });
    fetchExpenseSummary();
    fetchMonthlyTrends();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Financial Reports'),
        backgroundColor: const Color(0xFFD4AF37),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Spending Breakdown",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFD4AF37),
                    ),
                  ),
                  Row(
                    children: [
                      DropdownButton<int>(
                        value: selectedMonth,
                        items: List.generate(12, (i) => i + 1).map((int value) {
                          return DropdownMenuItem<int>(
                            value: value,
                            child: Text(monthLabels[value]),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedMonth = value!;
                            isLoading = true;
                          });
                          fetchExpenseSummary();
                        },
                      ),
                      const SizedBox(width: 10),
                      DropdownButton<int>(
                        value: selectedYear,
                        items: availableYears.map((int year) {
                          return DropdownMenuItem<int>(
                            value: year,
                            child: Text(year.toString()),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) _onYearChanged(value);
                        },
                      ),
                    ],
                  )
                ],
              ),
              const SizedBox(height: 10),
              categoryData.isEmpty
                  ? const Text("No data available")
                  : pc.PieChart(
                dataMap: categoryData,
                chartRadius: 180,
                chartValuesOptions: const pc.ChartValuesOptions(
                  showChartValuesInPercentage: true,
                ),
                colorList: [
                  Colors.amber,
                  Colors.blueAccent,
                  Colors.green,
                  Colors.red,
                  Colors.purple,
                  Colors.orange,
                  Colors.teal
                ],
              ),
              const SizedBox(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Monthly Trends",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFD4AF37),
                    ),
                  ),
                  DropdownButton<int>(
                    value: selectedYear,
                    items: availableYears.map((int year) {
                      return DropdownMenuItem<int>(
                        value: year,
                        child: Text(year.toString()),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) _onYearChanged(value);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 280,
                child: fl.BarChart(
                  fl.BarChartData(
                    maxY: 2000,
                    barTouchData: fl.BarTouchData(
                      enabled: true,
                      touchTooltipData: fl.BarTouchTooltipData(
                        tooltipBgColor: Colors.black.withOpacity(0.8),
                        tooltipRoundedRadius: 8,
                        tooltipPadding: const EdgeInsets.all(6),
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          final month = monthLabels[group.x.toInt()];
                          final amount = rod.toY.toStringAsFixed(0);
                          return fl.BarTooltipItem(
                            '$month\nRM$amount',
                            const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          );
                        },
                      ),
                    ),
                    titlesData: fl.FlTitlesData(
                      leftTitles: fl.AxisTitles(
                        sideTitles: fl.SideTitles(
                          showTitles: true,
                          reservedSize: 38,
                          getTitlesWidget: (value, _) => Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Text(
                              'RM${value.toInt()}',
                              style: const TextStyle(fontSize: 9),
                            ),
                          ),
                        ),
                      ),
                      bottomTitles: fl.AxisTitles(
                        sideTitles: fl.SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, _) => Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              monthLabels[value.toInt()],
                              style: const TextStyle(fontSize: 10, color: Colors.black87),
                            ),
                          ),
                        ),
                      ),
                    ),
                    borderData: fl.FlBorderData(show: false),
                    barGroups: monthlySpots.map((e) {
                      final index = e.x.toInt();
                      final color = Colors.primaries[index % Colors.primaries.length];
                      return fl.BarChartGroupData(
                        x: index,
                        barRods: [
                          fl.BarChartRodData(
                            toY: e.y,
                            width: 14,
                            borderRadius: BorderRadius.circular(6),
                            gradient: LinearGradient(
                              colors: [
                                color.shade400,
                                color.shade700,
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ],
                        showingTooltipIndicators: [0],
                      );
                    }).toList(),
                    gridData: fl.FlGridData(show: true),
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
