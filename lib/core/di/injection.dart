import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get_it/get_it.dart';
// Data (Implementation)
import '../../features/home/data/repositories/transaction_repository_impl.dart';
import '../../features/home/domain/repostories/transaction_repository.dart';

final getIt = GetIt.instance;

void setupDependencies() {
  // External
  getIt.registerLazySingleton(() => FirebaseFirestore.instance);
  getIt.registerLazySingleton(() => FirebaseAuth.instance);

  // Repository
  getIt.registerLazySingleton<TransactionRepository>(
        () => TransactionRepositoryImpl(
      firestore: getIt(),
      auth: getIt(),
    ),
  );
}