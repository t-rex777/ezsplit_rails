import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'screens/auth/accept_invite_screen.dart';
import 'screens/auth/forgot_password_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/expense/expense_detail_screen.dart';
import 'screens/expense/expense_form_screen.dart';
import 'screens/group_detail/group_detail_screen.dart';
import 'screens/groups/group_settings_screen.dart';
import 'screens/groups/groups_screen.dart';
import 'screens/groups/new_group_screen.dart';
import 'screens/placeholder_screen.dart';
import 'screens/shell.dart';
import 'state/session.dart';

const _publicPaths = {'/login', '/forgot', '/invite'};

final routerProvider = Provider<GoRouter>((ref) {
  // Full-screen forms use the root navigator so the tab bar hides behind them.
  final rootNavigatorKey = GlobalKey<NavigatorState>();
  final refresh = ValueNotifier<int>(0);
  ref.listen(sessionProvider, (_, _) => refresh.value++);

  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/home',
    refreshListenable: refresh,
    redirect: (context, state) {
      final path = state.uri.path;
      final session = ref.read(sessionProvider);
      final isPublic = _publicPaths.contains(path);

      // Wait for the saved session so a cold start doesn't flash /login.
      if (session.isLoading && !session.hasValue && !session.hasError) {
        return isPublic || path == '/splash' ? null : '/splash';
      }

      final signedIn = session.hasValue && session.value != null;
      if (path == '/splash') return signedIn ? '/home' : '/login';
      if (!signedIn && !isPublic) return '/login';
      // Accepting an invite signs the user in, which ends the invite flow too.
      if (signedIn && (path == '/login' || path == '/invite')) return '/home';
      if (path == '/invite' &&
          ((state.uri.queryParameters['token'] ?? '').isEmpty ||
              (state.uri.queryParameters['email'] ?? '').isEmpty)) {
        return '/login';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/forgot', builder: (_, _) => const ForgotPasswordScreen()),
      GoRoute(
        path: '/invite',
        builder: (_, state) => AcceptInviteScreen(
          token: state.uri.queryParameters['token'] ?? '',
          email: state.uri.queryParameters['email'] ?? '',
        ),
      ),
      // Outside the tab shell, so the tab bar hides behind them.
      GoRoute(
        path: '/expenses/:id',
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, state) => ExpenseDetailScreen(
          expenseId: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
        ),
        routes: [
          GoRoute(
            path: 'edit',
            parentNavigatorKey: rootNavigatorKey,
            builder: (_, state) => EditExpenseScreen(
              expenseId: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
            ),
          ),
        ],
      ),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => AppShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (_, _) => const PlaceholderScreen(title: 'Home'),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/groups',
                builder: (_, _) => const GroupsScreen(),
                routes: [
                  // `new` must come before `:id`.
                  GoRoute(
                    path: 'new',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (_, _) => const NewGroupScreen(),
                  ),
                  GoRoute(
                    path: ':id',
                    builder: (_, state) => GroupDetailScreen(
                      groupId:
                          int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
                      view: state.uri.queryParameters['view'],
                    ),
                    routes: [
                      GoRoute(
                        path: 'settings',
                        parentNavigatorKey: rootNavigatorKey,
                        builder: (_, state) => GroupSettingsScreen(
                          groupId:
                              int.tryParse(state.pathParameters['id'] ?? '') ??
                              0,
                        ),
                      ),
                      GoRoute(
                        path: 'expenses/new',
                        parentNavigatorKey: rootNavigatorKey,
                        builder: (_, state) => ExpenseFormScreen(
                          groupId:
                              int.tryParse(state.pathParameters['id'] ?? '') ??
                              0,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/activity',
                builder: (_, _) => const ActivityPlaceholder(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (_, _) => const PlaceholderScreen(title: 'Profile'),
                routes: [
                  GoRoute(
                    path: 'details',
                    builder: (_, _) =>
                        const PlaceholderScreen(title: 'Edit details'),
                  ),
                  GoRoute(
                    path: 'categories',
                    builder: (_, _) =>
                        const PlaceholderScreen(title: 'Categories'),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );

  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});
