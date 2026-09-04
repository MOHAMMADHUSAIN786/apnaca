import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'core/services/sync_service.dart';
import 'features/auth/domain/repositories/auth_repository.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/ai_chat/bloc/chat_bloc.dart';
import 'features/ai_chat/repository/ai_chat_repository.dart';
import 'features/ai_chat/service/agent_gateway_client.dart';
import 'features/ai_chat/service/openrouter_service.dart';
import 'features/splash/presentation/splash_screen.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. dotenv PEHLE load karo — baaki sab baad mein
  await dotenv.load(fileName: ".env");

  // Agent Gateway (Phase 2). Off unless .env opts in:
  //   AGENT_GATEWAY_URL=https://...run.app
  //   AGENT_GATEWAY_ENABLED=true
  final gatewayUrl = dotenv.env['AGENT_GATEWAY_URL'] ?? '';
  AgentGatewayConfig.baseUrl = gatewayUrl;
  AgentGatewayConfig.enabled =
      gatewayUrl.isNotEmpty && dotenv.env['AGENT_GATEWAY_ENABLED'] == 'true';

  // 2. Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 3. Firestore offline persistence — critical for team members
  // Without this, team_access doc returns null when offline
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes:     Settings.CACHE_SIZE_UNLIMITED,
  );



  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // dotenv ab safe hai — yahan read karo
    final openRouterKey = dotenv.env['OPENROUTER_KEY'] ?? '';

    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider(create: (_) => AuthRepository()),
        RepositoryProvider(
          create: (_) => AiChatRepository(
            llm: OpenRouterService(apiKey: openRouterKey),
          ),
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (context) => AuthBloc(
              authRepository: context.read<AuthRepository>(),
            ),
          ),
          BlocProvider(
            create: (context) => ChatBloc(
              repository: context.read<AiChatRepository>(),
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
      ),
    );
  }
}