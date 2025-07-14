import 'package:electricity_prices_and_carbon_intensity/widgets/chart.dart';
import 'package:electricity_prices_and_carbon_intensity/utilities/httpclient.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'widgets/animatedCounter.dart';
// import 'utilities/nativeAdapter.dart';

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
      home: const MyHomePage(title: 'Current Carbon Intensity'),
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
  late int _counter = 0;
  final _caller = CarbonIntensityCaller();
  late CarbonIntensityChartGeneratorFactory _chartGeneratorFactory;
  AdaptiveChartWidgetBuilder? _adaptiveChartWidgetBuilder;

  void _resetCounter() {
    setState(() {
      _counter = 0;
    });
  }

  Future<int> _getCarbonIntensity() async {
    try {
      // return await NativeAdapter.updateCarbonIntensity();
      final intensity = await _caller.getCurrentIntensity();
      return CarbonIntensityCaller.convertToInt(intensity);
    } on Exception catch (e) {
      logger.e(e.toString());
      return -1;
    }
  }

  Future<void> _refreshCarbonIntensity() async {
    _resetCounter();
    int ci = -1;
    ci = await _getCarbonIntensity();

    if (ci != -1) {
      for (int i = 0; i <= ci; i++) {
        setState(() {
          _counter = i;
        });
      }
    } else {
      logger.e("Could not fetch latest CI");
    }
  }

  Future<void> _refreshChartData() async {
    final _chartGenerator = await _chartGeneratorFactory.getChartGenerator();
    setState(() {
      _adaptiveChartWidgetBuilder = AdaptiveChartWidgetBuilder(_chartGenerator);
    });
  }

  @override
  void initState() {
    super.initState();
    _chartGeneratorFactory = CarbonIntensityChartGeneratorFactory(
      _caller,
      setState,
    );
    _refreshCarbonIntensity();
    _refreshChartData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            // BigCounter(counter: _counter),
            BigAnimatedCounter(count: _counter),
            SizedBox(height: 40),
            _adaptiveChartWidgetBuilder == null
                ? SizedBox()
                : LayoutBuilder(builder: _adaptiveChartWidgetBuilder!.builder),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _refreshChartData,
        tooltip: 'Refresh Carbon Intensity',
        child: const Icon(Icons.refresh_rounded),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}

class BigAnimatedCounter extends AnimatedCounter {
  static const Duration ONE_SECOND = Duration(seconds: 1);

  const BigAnimatedCounter({
    super.key,
    required super.count,
    super.curve = Curves.fastOutSlowIn,
  }) : super(duration: ONE_SECOND, textWrapper: _bigText);

  static Widget _bigText(String text, ThemeData theme) {
    final textStyle = theme.textTheme.displayLarge!.copyWith(
      color: theme.colorScheme.primary,
    );

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text(text, style: textStyle),
    );
  }
}
