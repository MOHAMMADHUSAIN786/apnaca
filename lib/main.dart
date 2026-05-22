import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'features/auth/domain/repositories/auth_repository.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/splash/presentation/splash_screen.dart';

void main() async {

  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {

    return RepositoryProvider(

      create: (_) => AuthRepository(),

        child: MultiBlocProvider(

          providers: [

            BlocProvider(

              create: (context) => AuthBloc(
                authRepository:
                context.read<AuthRepository>(),
              ),
            ),


          ],

          child: ScreenUtilInit(

            designSize: const Size(375, 812),

            minTextAdapt: true,

            splitScreenMode: true,

            builder: (context, child) {

              return MaterialApp(

                debugShowCheckedModeBanner: false,

                theme: ThemeData(

                  splashColor: Colors.transparent,

                  highlightColor: Colors.transparent,
                ),

                home: const SplashScreen(),
              );
            },
          ),
        ));
  }
}