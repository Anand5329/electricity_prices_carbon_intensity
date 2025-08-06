import 'package:electricity_prices_and_carbon_intensity/utilities/style.dart';
import 'package:electricity_prices_and_carbon_intensity/widgets/electricity.dart';
import 'package:electricity_prices_and_carbon_intensity/widgets/carbonIntensity.dart';
import 'package:electricity_prices_and_carbon_intensity/widgets/gas.dart';
import 'package:electricity_prices_and_carbon_intensity/widgets/historicalCarbonIntensity.dart';
import 'package:electricity_prices_and_carbon_intensity/widgets/regionaldata.dart';
import 'package:electricity_prices_and_carbon_intensity/widgets/settings.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';

void main() async {
  await initializeDateFormatting(Intl.systemLocale, null);
  runApp(const MyApp());
}

var logger = Logger(filter: null, printer: PrettyPrinter(), output: null);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Carbon Intensity App',
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: [Locale("en", "GB"), Locale("en", "US")],
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
    // NavigationDestination(icon: Icon(Icons.co2_sharp), label: "National CI"),
    NavigationDestination(
      icon: Icon(Icons.co2_sharp),
      label: "Intensity",
      tooltip: "Regional Carbon Intensity",
      selectedIcon: Icon(Icons.co2_rounded),
    ),
    NavigationDestination(
      icon: Icon(Icons.history_sharp),
      label: "Historical",
      tooltip: "Historical Carbon Intensity",
      selectedIcon: Icon(Icons.history_rounded),
    ),
    NavigationDestination(
      icon: Icon(Icons.bolt_sharp),
      label: "Electricity",
      tooltip: "Octopus Electricity Prices",
      selectedIcon: Icon(Icons.bolt_rounded),
    ),
    NavigationDestination(
      icon: Icon(Icons.local_fire_department_sharp),
      label: "Gas",
      tooltip: "Octopus Gas Prices",
      selectedIcon: Icon(Icons.local_fire_department_rounded),
    ),
    // disabled for web devices since saving not supported
    NavigationDestination(
      icon: Icon(Icons.settings),
      label: "Settings",
      tooltip: "Configuration Settings",
      selectedIcon: Icon(Icons.settings_rounded),
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
      const HistoricalCarbonIntensityPage(),
      const ElectricityPricesPage(),
      const GasPricesPage(),
      const SettingsPage(),
    ];
    _pageController = PageController(initialPage: _selectedIndex);

    _railDestinations = _destinations
        .map(
          (d) => NavigationRailDestination(
            icon: d.icon,
            selectedIcon: d.selectedIcon,
            label: Text(d.label, style: StyleComponents.smallText),
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
                  labelTextStyle: WidgetStateProperty.all(
                    StyleComponents.centerText,
                  ),
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
