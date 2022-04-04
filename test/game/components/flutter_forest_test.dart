// ignore_for_file: cascade_invocations

import 'package:bloc_test/bloc_test.dart';
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pinball/game/game.dart';
import 'package:pinball_components/pinball_components.dart';

import '../../helpers/helpers.dart';

void beginContact(Forge2DGame game, BodyComponent bodyA, BodyComponent bodyB) {
  assert(
    bodyA.body.fixtures.isNotEmpty && bodyB.body.fixtures.isNotEmpty,
    'Bodies require fixtures to contact each other.',
  );

  final fixtureA = bodyA.body.fixtures.first;
  final fixtureB = bodyB.body.fixtures.first;
  final contact = Contact.init(fixtureA, 0, fixtureB, 0);
  game.world.contactManager.contactListener?.beginContact(contact);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final flameTester = FlameTester(PinballGameTest.create);

  group('FlutterForest', () {
    flameTester.test(
      'loads correctly',
      (game) async {
        await game.ready();
        final flutterForest = FlutterForest();
        await game.ensureAdd(flutterForest);

        expect(game.contains(flutterForest), isTrue);
      },
    );

    group('loads', () {
      flameTester.test(
        'a FlutterSignPost',
        (game) async {
          await game.ready();
          final flutterForest = FlutterForest();
          await game.ensureAdd(flutterForest);

          expect(
            flutterForest.descendants().whereType<FlutterSignPost>().length,
            equals(1),
          );
        },
      );

      flameTester.test(
        'a BigDashNestBumper',
        (game) async {
          await game.ready();
          final flutterForest = FlutterForest();
          await game.ensureAdd(flutterForest);

          expect(
            flutterForest.descendants().whereType<BigDashNestBumper>().length,
            equals(1),
          );
        },
      );

      flameTester.test(
        'two SmallDashNestBumper',
        (game) async {
          await game.ready();
          final flutterForest = FlutterForest();
          await game.ensureAdd(flutterForest);

          expect(
            flutterForest.descendants().whereType<SmallDashNestBumper>().length,
            equals(2),
          );
        },
      );
    });

    group('controller', () {
      group('listenWhen', () {
        final gameBloc = MockGameBloc();
        final flameBlocTester = FlameBlocTester<TestGame, GameBloc>(
          gameBuilder: TestGame.new,
          blocBuilder: () => gameBloc,
        );

        flameBlocTester.testGameWidget(
          'listens when a Bonus.dashNest is added',
          verify: (game, tester) async {
            final flutterForest = FlutterForest();

            const state = GameState(
              score: 0,
              balls: 3,
              activatedBonusLetters: [],
              activatedDashNests: {},
              bonusHistory: [GameBonus.dashNest],
            );
            expect(
              flutterForest.controller
                  .listenWhen(const GameState.initial(), state),
              isTrue,
            );
          },
        );
      });
    });

    flameTester.test(
      'onNewState adds a new ball',
      (game) async {
        final flutterForest = FlutterForest();
        await game.ready();
        await game.ensureAdd(flutterForest);

        final previousBalls = game.descendants().whereType<Ball>().length;
        flutterForest.controller.onNewState(MockGameState());
        await game.ready();

        expect(
          game.descendants().whereType<Ball>().length,
          greaterThan(previousBalls),
        );
      },
    );

    group('bumpers', () {
      late Ball ball;
      late GameBloc gameBloc;

      setUp(() {
        ball = Ball(baseColor: const Color(0xFF00FFFF));
        gameBloc = MockGameBloc();
        whenListen(
          gameBloc,
          const Stream<GameState>.empty(),
          initialState: const GameState.initial(),
        );
      });

      final flameBlocTester = FlameBlocTester<PinballGame, GameBloc>(
        gameBuilder: PinballGameTest.create,
        blocBuilder: () => gameBloc,
      );

      flameBlocTester.testGameWidget(
        'add DashNestActivated event',
        setUp: (game, tester) async {
          await game.ready();
          final flutterForest =
              game.descendants().whereType<FlutterForest>().first;
          await game.ensureAdd(ball);

          final bumpers =
              flutterForest.descendants().whereType<DashNestBumper>();

          for (final bumper in bumpers) {
            beginContact(game, bumper, ball);
            final controller = bumper.firstChild<DashNestBumperController>()!;
            verify(
              () => gameBloc.add(DashNestActivated(controller.id)),
            ).called(1);
          }
        },
      );

      flameBlocTester.testGameWidget(
        'add Scored event',
        setUp: (game, tester) async {
          final flutterForest = FlutterForest();
          await game.ensureAdd(flutterForest);
          await game.ensureAdd(ball);

          final bumpers =
              flutterForest.descendants().whereType<DashNestBumper>();

          for (final bumper in bumpers) {
            beginContact(game, bumper, ball);
            final points = (bumper as ScorePoints).points;
            verify(
              () => gameBloc.add(Scored(points: points)),
            ).called(1);
          }
        },
      );
    });
  });

  group('DashNestBumperController', () {
    late DashNestBumper dashNestBumper;

    setUp(() {
      dashNestBumper = MockDashNestBumper();
    });

    group(
      'listensWhen',
      () {
        late GameState previousState;
        late GameState newState;

        setUp(
          () {
            previousState = MockGameState();
            newState = MockGameState();
          },
        );

        test('listens when the id is added to activatedDashNests', () {
          const id = '';
          final controller = DashNestBumperController(
            dashNestBumper,
            id: id,
          );

          when(() => previousState.activatedDashNests).thenReturn({});
          when(() => newState.activatedDashNests).thenReturn({id});

          expect(controller.listenWhen(previousState, newState), isTrue);
        });

        test('listens when the id is removed from activatedDashNests', () {
          const id = '';
          final controller = DashNestBumperController(
            dashNestBumper,
            id: id,
          );

          when(() => previousState.activatedDashNests).thenReturn({id});
          when(() => newState.activatedDashNests).thenReturn({});

          expect(controller.listenWhen(previousState, newState), isTrue);
        });

        test("doesn't listen when the id is never in activatedDashNests", () {
          final controller = DashNestBumperController(
            dashNestBumper,
            id: '',
          );

          when(() => previousState.activatedDashNests).thenReturn({});
          when(() => newState.activatedDashNests).thenReturn({});

          expect(controller.listenWhen(previousState, newState), isFalse);
        });

        test("doesn't listen when the id still in activatedDashNests", () {
          const id = '';
          final controller = DashNestBumperController(
            dashNestBumper,
            id: id,
          );

          when(() => previousState.activatedDashNests).thenReturn({id});
          when(() => newState.activatedDashNests).thenReturn({id});

          expect(controller.listenWhen(previousState, newState), isFalse);
        });
      },
    );

    group(
      'onNewState',
      () {
        late GameState state;

        setUp(() {
          state = MockGameState();
        });

        test(
          'activates the bumper when id in activatedDashNests',
          () {
            const id = '';
            final controller = DashNestBumperController(
              dashNestBumper,
              id: id,
            );

            when(() => state.activatedDashNests).thenReturn({id});
            controller.onNewState(state);

            verify(() => dashNestBumper.activate()).called(1);
          },
        );

        test(
          'deactivates the bumper when id not in activatedDashNests',
          () {
            final controller = DashNestBumperController(
              dashNestBumper,
              id: '',
            );

            when(() => state.activatedDashNests).thenReturn({});
            controller.onNewState(state);

            verify(() => dashNestBumper.deactivate()).called(1);
          },
        );
      },
    );
  });
}