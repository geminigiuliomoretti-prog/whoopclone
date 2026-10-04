import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/constants/whoop_theme.dart';
import 'data/repositories/sqlite_whoop_repository.dart';
import 'viewmodels/whoop_viewmodel.dart';
import 'views/main_navigation_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const WhoopApp());
}

class WhoopApp extends StatelessWidget {
  const WhoopApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<WhoopViewModel>(
          create: (_) {
            final viewModel = WhoopViewModel(
              repository: SqliteWhoopRepository(),
            );
            viewModel.loadData();
            return viewModel;
          },
        ),
      ],
      child: MaterialApp(
        title: 'WHOOP 5.0 Clone',
        debugShowCheckedModeBanner: false,
        theme: WhoopTheme.darkTheme,
        home: const MainNavigationScreen(),
      ),
    );
  }
}
