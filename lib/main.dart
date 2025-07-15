import 'package:electricity_prices_and_carbon_intensity/electricty.dart';
import 'package:electricity_prices_and_carbon_intensity/widgets/carbonIntensity.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';

void main() {
  runApp(const MyApp());
}

var logger = Logger(filter: null, printer: PrettyPrinter(), output: null);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.lightGreen),
      ),
      // home: const MyHomePage(title: 'Current Carbon Intensity'),
      home: const MyHomePage(title: "title"),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late final List<NavigationDestination> _destinations = [
    NavigationDestination(icon: Icon(Icons.co2_sharp), label: "Carbon Intensity"),
    NavigationDestination(icon: Icon(Icons.bolt_sharp), label: "Electricity Prices")
  ];
  late final List<NavigationRailDestination> _railDestinations;
  int _selectedIndex = 0;

  static const int _widthThreshold = 600;
  static const int _largeWidthThreshold = 1000;

  @override
  void initState() {
    _railDestinations = _destinations.map((d) => NavigationRailDestination(icon: d.icon, label: Text(d.label))).toList();
  }

  void _onDestinationSelected(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget page;
    switch (_selectedIndex) {
      case 0:
        page = CarbonIntensityPage();
        break;
      case 1:
        page = ElectricityPricesPage();
        break;
      default:
        throw UnimplementedError(
          "Unimplemented page for index $_selectedIndex",
        );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        return constraints.maxWidth < _widthThreshold
            ? Scaffold(
                bottomNavigationBar: NavigationBar(
                  destinations: _destinations,
                  onDestinationSelected: _onDestinationSelected,
                  selectedIndex: _selectedIndex,
                ),
                body: page,
              )
            : Scaffold(
                body: Row(
                  children: [
                    SafeArea(
                        child: NavigationRail(
                            destinations: _railDestinations,
                            onDestinationSelected: _onDestinationSelected,
                            selectedIndex: _selectedIndex,
                            extended: constraints.maxWidth > _largeWidthThreshold,
                        )
                    ),
                    Expanded(
                        child: page
                    )
                  ],
                )
        );
      },
    );
  }
}
