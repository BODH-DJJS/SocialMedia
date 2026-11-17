import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'providers/auth_provider.dart';
import 'providers/event_provider.dart';
import 'providers/dev_pipeline_provider.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/event_detail_screen.dart';
import 'screens/admin_assign_screen.dart';
import 'screens/dev_pipeline_screen.dart';
import 'models/event.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final authProvider = AuthProvider();
  await authProvider.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authProvider),
        ChangeNotifierProvider(create: (_) => EventProvider()),
        ChangeNotifierProvider(create: (_) => DevPipelineProvider()),
      ],
      child: const BodhSocialMediaApp(),
    ),
  );
}

class BodhSocialMediaApp extends StatelessWidget {
  const BodhSocialMediaApp({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    final goRouter = GoRouter(
      initialLocation: authProvider.isLoggedIn ? '/dashboard' : '/login',
      routes: [
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/dashboard',
          builder: (context, state) {
            final tabParam = state.uri.queryParameters['tab'];
            final pipelineParam = state.uri.queryParameters['pipeline'];
            return DashboardScreen(
              initialTab: tabParam,
              initialPipeline: pipelineParam,
            );
          },
        ),
        GoRoute(
          path: '/event',
          builder: (context, state) {
            final event = state.extra is Event ? state.extra as Event : null;
            final postNo = state.uri.queryParameters['postNo'] ?? '';
            final stage = state.uri.queryParameters['stage'] ?? '';
            final taskId = state.uri.queryParameters['taskId'] ?? '';
            final isCombined = state.uri.queryParameters['isCombined'] == 'true';
            return EventDetailScreen(
              event: event,
              postNo: postNo,
              stage: stage,
              taskId: taskId,
              isCombined: isCombined,
            );
          },
        ),
        GoRoute(
          path: '/dev-pipeline',
          builder: (context, state) => DevPipelineScreen(
            onSwitchToSocialMedia: () => context.go('/dashboard'),
          ),
        ),
        GoRoute(
          path: '/admin-assign',
          builder: (context, state) {
            Map<String, dynamic> postData = {};
            if (state.extra is Map<String, dynamic>) {
              postData = state.extra as Map<String, dynamic>;
            } else {
              final postNo = state.uri.queryParameters['postNo'] ?? '';
              final isCombinedParam = state.uri.queryParameters['isCombined'] == 'true';
              final provider = context.read<EventProvider>();

              if (isCombinedParam) {
                final combinedPosts = provider.rawPosts
                    .where((p) => p['GroupID']?.toString() == postNo)
                    .toList();
                final postTasks = provider.events.where((t) => t.postNo == postNo).toList();
                postData = {
                  'postNo': postNo,
                  'GroupID': postNo,
                  'isCombined': true,
                  'isInitialized': postTasks.isNotEmpty,
                  'existingTasks': postTasks,
                  'combinedPosts': combinedPosts,
                  if (combinedPosts.isNotEmpty) ...combinedPosts.first,
                };
              } else {
                final foundPost = provider.rawPosts.firstWhere(
                  (p) => p['PostNo']?.toString() == postNo,
                  orElse: () => {'PostNo': postNo},
                );
                final postTasks = provider.events.where((t) => t.postNo == postNo).toList();
                postData = {
                  ...foundPost,
                  'isInitialized': postTasks.isNotEmpty,
                  'existingTasks': postTasks,
                };
              }
            }
            return AdminAssignScreen(postData: postData);
          },
        ),
      ],
      redirect: (context, state) {
        final isLoggedIn = authProvider.isLoggedIn;
        final isLoggingIn = state.matchedLocation == '/login';

        if (!isLoggedIn && !isLoggingIn) return '/login';
        if (isLoggedIn && isLoggingIn) return '/dashboard';
        return null;
      },
    );

    return MaterialApp.router(
      title: 'BODH Social Media',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF1A237E),
          secondary: Color(0xFFFF6F00),
          tertiary: Color(0xFF00897B),
          surface: Colors.white,
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: Color(0xFF1A1A2E),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1A237E),
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
        ),
        cardTheme: CardTheme(
          elevation: 2,
          shadowColor: Colors.black26,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF1A237E),
          selectedItemColor: Color(0xFFFF6F00),
          unselectedItemColor: Colors.white60,
          type: BottomNavigationBarType.fixed,
          elevation: 8,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF5F7FA),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF1A237E), width: 2)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
      routerConfig: goRouter,
    );
  }
}
