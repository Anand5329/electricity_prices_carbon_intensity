import 'package:electricity_prices_and_carbon_intensity/widgets/electricity.dart';
import 'package:electricity_prices_and_carbon_intensity/widgets/carbonIntensity.dart';
import 'package:electricity_prices_and_carbon_intensity/widgets/gas.dart';
import 'package:electricity_prices_and_carbon_intensity/widgets/regionaldata.dart';
import 'package:electricity_prices_and_carbon_intensity/widgets/settings.dart';
import 'package:flutter/foundation.dart';
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

// TODO: add pages for historical data
class _MyHomePageState extends State<MyHomePage> {
  late final List<NavigationDestination> _destinations = [
    // NavigationDestination(icon: Icon(Icons.co2_sharp), label: "National CI"),
    NavigationDestination(icon: Icon(Icons.co2_sharp), label: "Regional CI"),
    NavigationDestination(
      icon: Icon(Icons.bolt_sharp),
      label: "Electricity Prices",
    ),
    NavigationDestination(
      icon: Icon(Icons.local_fire_department_sharp),
      label: "Gas Prices",
    ),
    // disabled for web devices since saving not supported
    NavigationDestination(
      icon: Icon(Icons.settings),
      label: "Settings",
      enabled: !kIsWeb,
    ),
  ];
  late final List<NavigationRailDestination> _railDestinations;
  int _selectedIndex = 0;

  late final List<Widget> pages;
  late final PageController _pageController;

  static const int _widthThreshold = 600;
  static const int _largeWidthThreshold = 1000;

  @override
  void initState() {
    super.initState();
    pages = [
      // const CarbonIntensityPage(),
      const RegionalPage(),
      const ElectricityPricesPage(),
      const GasPricesPage(),
      const SettingsPage(),
    ];
    _pageController = PageController(initialPage: _selectedIndex);

    _railDestinations = _destinations
        .map(
          (d) => NavigationRailDestination(
            icon: d.icon,
            label: Text(d.label),
            disabled: !d.enabled,
          ),
        )
        .toList();
  }

  void _onDestinationSelected(int index) {
    setState(() {
      _selectedIndex = index;
      _pageController.jumpToPage(_selectedIndex);
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget page = PageView(
      controller: _pageController,
      physics: NeverScrollableScrollPhysics(),
      children: pages,
    );
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
                      ),
                    ),
                    Expanded(child: page),
                  ],
                ),
              );
      },
    );
  }
}
