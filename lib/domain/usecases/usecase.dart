import 'package:equatable/equatable.dart';

/// UseCase 基类
/// [Type] - 返回类型
/// [Params] - 参数类型
abstract class UseCase<Type, Params> {
  Future<Type> call(Params params);
}

/// 无参数的 UseCase
abstract class UseCaseNoParams<Type> {
  Future<Type> call();
}

/// 无参数占位类
class NoParams extends Equatable {
  const NoParams();

  @override
  List<Object?> get props => [];
}
