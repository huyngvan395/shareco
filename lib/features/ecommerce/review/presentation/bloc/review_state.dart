import 'package:equatable/equatable.dart';

abstract class ReviewState extends Equatable {
  const ReviewState();

  @override
  List<Object?> get props => [];
}

class ReviewInitial extends ReviewState {}

class ReviewSubmitting extends ReviewState {}

class ReviewSubmitSuccess extends ReviewState {}

class ReviewSubmitFailure extends ReviewState {
  final String message;

  const ReviewSubmitFailure(this.message);

  @override
  List<Object?> get props => [message];
}
