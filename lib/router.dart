import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'screens/auth/accept_invite_screen.dart';
import 'screens/auth/forgot_password_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/placeholder_screen.dart';
import 'screens/shell.dart';
import 'state/session.dart';

const _publicPaths = {'/login', '/forgot', '/invite'};

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(sessionProvider, (_, _) => refresh.value++);

  final router = GoRouter(
    initialLocation: '/home',
    refreshListenable: refresh,
    redirect: (context, state) {
      final path = state.uri.path;
      final session = ref.read(sessionProvider);
      final isPublic = _publicPaths.contains(path);

      // Wait for the saved session so a cold start doesn't flash /login.
      if (session.isLoading && !session.hasValue) {
        return isPublic || path == '/splash' ? null : '/splash';
      }

      final signedIn = session.value != null;
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
                builder: (_, _) => const PlaceholderScreen(title: 'Groups'),
                routes: [
                  // `new` must come before `:id`.
                  GoRoute(
                    path: 'new',
                    builder: (_, _) =>
                        const PlaceholderScreen(title: 'New group'),
                  ),
                  GoRoute(
                    path: ':id',
                    builder: (_, state) => PlaceholderScreen(
                      title: 'Group ${state.pathParameters['id']}',
                      detail: 'View: ${_groupView(state)}',
                    ),
                    routes: [
                      GoRoute(
                        path: 'settings',
                        builder: (_, _) =>
                            const PlaceholderScreen(title: 'Group settings'),
                      ),
                      GoRoute(
                        path: 'expenses/new',
                        builder: (_, _) =>
                            const PlaceholderScreen(title: 'Add expense'),
                      ),
                    ],
                  ),
                ],
              ),
              GoRoute(
                path: '/expenses/:id',
                builder: (_, state) => PlaceholderScreen(
                  title: 'Expense ${state.pathParameters['id']}',
                ),
                routes: [
                  GoRoute(
                    path: 'edit',
                    builder: (_, _) =>
                        const PlaceholderScreen(title: 'Edit expense'),
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

String _groupView(GoRouterState state) {
  const views = {'expenses', 'balances', 'totals'};
  final view = state.uri.queryParameters['view'];
  return views.contains(view) ? view! : 'expenses';
}
