import 'package:amplify_api/amplify_api.dart';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:amplify_authenticator/amplify_authenticator.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'amplifyconfiguration.dart';
import 'models/ModelProvider.dart';

import 'dart:convert';
import 'dart:async';

import 'package:http/http.dart' as http;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _configureAmplify();
  runApp(const MyApp());
}

Future<void> _configureAmplify() async {
  try {
    // Create the API plugin.
    //
    // If `ModelProvider.instance` is not available, try running
    // `amplify codegen models` from the root of your project.
    final api = AmplifyAPI(
        options: APIPluginOptions(modelProvider: ModelProvider.instance));

    // Create the Auth plugin.
    final auth = AmplifyAuthCognito();

    // Add the plugins and configure Amplify for your app.
    await Amplify.addPlugins([api, auth]);
    await Amplify.configure(amplifyconfig);

    safePrint('Successfully configured');
  } on Exception catch (e) {
    safePrint('Error configuring Amplify: $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // GoRouter configuration
  static final _router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const HomeScreen(),
      ),
      // Can add the robot detail screen here later
      // GoRoute(
      //   path: '/manage-budget-entry',
      //   name: 'manage',
      //   builder: (context, state) => ManageBudgetEntryScreen(
      //     budgetEntry: state.extra as BudgetEntry?,
      //   ),
      // ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return Authenticator(
      child: MaterialApp.router(
        routerConfig: _router,
        debugShowCheckedModeBanner: false,
        builder: Authenticator.builder(),
      ),
    );
  }
}

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<Robot>> futureAlbum;

  @override
  void initState() {
    super.initState();
    futureAlbum = fetchAlbum();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Robot List',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Robot List'),
        ),
        body: Center(
          child: FutureBuilder<List<Robot>>(
            future: futureAlbum,
            builder: (context, snapshot) {
              // ignore: avoid_print
              print('snapshotdata: $snapshot.data');
              if (snapshot.hasData) {
                final robots = snapshot.data;
                return buildRobots(robots!);
              } else if (snapshot.hasError) {
                return Text('${snapshot.error}');
              }

              // By default, show a loading spinner.
              return const CircularProgressIndicator();
            },
          ),
        ),
      ),
    );
  }
}

Widget buildRobots(List<Robot> robots) {
  return ListView.builder(
    itemCount: robots.length,
    itemBuilder: (context, index) {
      final robot = robots[index];
      return Container(
        color: Colors.grey.shade300,
        margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 5),
        height: 100,
        width: double.maxFinite,
        child: Row(
          children: [
            Expanded(flex: 3, child: Text(robot.title!)),
          ],
        ),
      );
    },
  );
}

Future<List<Robot>> fetchAlbum() async {
  var url = Uri.parse('https://jsonplaceholder.typicode.com/albums');
  final response =
      await http.get(url, headers: {"Content-Type": "application/json"});

  if (response.statusCode == 200) {
    // If the server did return a 200 OK response,
    // then parse the JSON.

    final List body = json.decode(response.body);

    return body.map((e) => Robot.fromJson(e)).toList();
  } else {
    // If the server did not return a 200 OK response,
    // then throw an exception.
    throw Exception('Failed to load album');
  }
}

class Robot {
  int? userId;
  int? id;
  String? title;

  Robot({this.userId, this.id, this.title});

  Robot.fromJson(Map<String, dynamic> json) {
    userId = json['userId'];
    id = json['id'];
    title = json['title'];
  }
}
