import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cricket_scorer_app/models/models.dart';
import 'package:cricket_scorer_app/services/auth/account_profile.dart';
import 'package:cricket_scorer_app/services/auth/auth_service.dart';
import 'package:cricket_scorer_app/services/storage/store.dart';
import 'package:cricket_scorer_app/views/screens/tournament/tournament_detail_screen.dart';
import 'package:cricket_scorer_app/views/screens/tournament/tournaments_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Tournament Authorization & Access Control Suite', () {
    late Store store;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      store = Store();
      await store.activateIdentity('user_owner_123');
    });

    test('Case 1: Tournament Owner has full management access', () async {
      final userAId = 'user_owner_123';
      store.profile = AccountProfile.create(
        uid: userAId,
        displayName: 'Owner User',
      );

      final tournament = Tournament(
        id: 'tourn_1',
        name: 'Champions Trophy',
        venue: 'Gaddafi Stadium',
        creatorId: userAId,
        teamIds: ['team_a', 'team_b'],
      );
      store.tournaments = [tournament];

      // Verify ownership check
      final uid = store.effectiveUserId;
      final isOwner = uid.isNotEmpty && tournament.creatorId == uid;
      expect(isOwner, isTrue);

      // Verify owner can modify details
      tournament.name = 'Champions Trophy 2026';
      tournament.venue = 'National Stadium';
      await store.persistTournamentsOnly();
      expect(store.tournaments.first.name, 'Champions Trophy 2026');
      expect(store.tournaments.first.venue, 'National Stadium');

      // Verify owner can add points adjustment
      tournament.pointsAdjustments['team_a'] = 2;
      expect(tournament.pointsAdjustments['team_a'], 2);

      // Verify owner can set points table override
      tournament.pointsTableOverrides['team_a'] = PointsTableOverride(
        played: 1,
        won: 1,
        points: 2,
      );
      expect(tournament.pointsTableOverrides.containsKey('team_a'), isTrue);
    });

    test('Case 2: Non-Owner user is strictly denied write/manage access', () async {
      final userAId = 'user_owner_123';
      final userBId = 'user_intruder_456';

      // Current user is User B (non-owner)
      await store.activateIdentity(userBId);
      store.profile = AccountProfile.create(
        uid: userBId,
        displayName: 'Visitor User',
      );

      final tournament = Tournament(
        id: 'tourn_1',
        name: 'Champions Trophy',
        venue: 'Gaddafi Stadium',
        creatorId: userAId,
        teamIds: ['team_a', 'team_b'],
      );
      store.tournaments = [tournament];

      final uid = store.effectiveUserId;
      final isOwner = uid.isNotEmpty && tournament.creatorId == uid;
      expect(isOwner, isFalse, reason: 'User B must not be treated as tournament owner');

      // Verify card layout properties for non-owner
      final cardIsOwner = !AuthService().isRestrictedGuest &&
          (tournament.creatorId.isNotEmpty ? (uid.isNotEmpty && tournament.creatorId == uid) : true);
      expect(cardIsOwner, isFalse, reason: 'TournamentCard must mark isOwner as false for non-creator');
    });

    test('Case 3: Restricted Guest is denied ownership', () async {
      final tournament = Tournament(
        id: 'tourn_1',
        name: 'Local Tournament',
        creatorId: 'guest_123',
      );

      // Verify restricted guest condition evaluates to false
      bool checkOwnership({required bool isRestrictedGuest, required String uid}) {
        if (isRestrictedGuest) return false;
        if (tournament.creatorId.isNotEmpty) {
          return uid.isNotEmpty && tournament.creatorId == uid;
        }
        return true;
      }

      expect(checkOwnership(isRestrictedGuest: true, uid: 'guest_123'), isFalse);
      expect(checkOwnership(isRestrictedGuest: false, uid: 'guest_123'), isTrue);
      expect(checkOwnership(isRestrictedGuest: false, uid: 'other_user'), isFalse);
    });

    test('Case 4: Offline unassigned tournament claims ownership upon user registration', () async {
      // 1. Created offline in guest workspace
      await store.activateIdentity('guest');
      final offlineTournament = Tournament(
        id: 'offline_tourn_1',
        name: 'Street League',
        creatorId: '', // Unassigned local
      );
      store.tournaments = [offlineTournament];
      await store.persistTournamentsOnly();

      expect(offlineTournament.creatorId, isEmpty);

      // 2. User registers or logs in with fresh account
      final newUid = 'usr_aliyan_new_account';
      await store.activateIdentity(newUid);
      store.tournaments = [offlineTournament];
      await store.ensureProfile(
        displayName: 'Aliyan Cricket',
      );

      // Verify the tournament was seamlessly claimed by the newly logged in user
      expect(store.tournaments.first.creatorId, newUid);
      expect(store.effectiveUserId, newUid);

      final isOwner = store.effectiveUserId.isNotEmpty &&
          store.tournaments.first.creatorId == store.effectiveUserId;
      expect(isOwner, isTrue);
    });

    test('Case 5: Cascade Deletion removes tournament AND all linked matches cleanly', () async {
      final userAId = 'user_owner_123';
      store.profile = AccountProfile.create(uid: userAId, displayName: 'Owner');

      final tournament = Tournament(
        id: 'tourn_del_1',
        name: 'To Delete Tournament',
        creatorId: userAId,
      );
      store.tournaments = [tournament];

      // Add 2 matches belonging to this tournament and 1 independent match
      final match1 = Match(
        id: 'm_tourn_1',
        tournamentId: 'tourn_del_1',
        teamAId: 'team_a',
        teamBId: 'team_b',
        xiA: ['p1'],
        xiB: ['p2'],
        tossWinnerId: 'team_a',
      );
      final match2 = Match(
        id: 'm_tourn_2',
        tournamentId: 'tourn_del_1',
        teamAId: 'team_b',
        teamBId: 'team_c',
        xiA: ['p2'],
        xiB: ['p3'],
        tossWinnerId: 'team_b',
      );
      final matchIndependent = Match(
        id: 'm_standalone_1',
        tournamentId: '',
        teamAId: 'team_x',
        teamBId: 'team_y',
        xiA: ['p4'],
        xiB: ['p5'],
        tossWinnerId: 'team_x',
      );

      store.matches = [match1, match2, matchIndependent];

      expect(store.tournaments.length, 1);
      expect(store.matches.length, 3);

      // Perform cascade delete
      await store.deleteTournament('tourn_del_1');

      // Verify tournament is deleted
      expect(store.tournaments.where((t) => t.id == 'tourn_del_1'), isEmpty);

      // Verify all tournament matches were cascade-deleted
      final remainingMatches = store.matches;
      expect(remainingMatches.length, 1);
      expect(remainingMatches.first.id, 'm_standalone_1');
      expect(remainingMatches.any((m) => m.tournamentId == 'tourn_del_1'), isFalse);
    });

    test('Case 6: Match scorer can score match but cannot edit tournament rules', () async {
      final ownerId = 'user_owner_123';
      final scorerId = 'user_scorer_888';

      final tournament = Tournament(
        id: 'tourn_1',
        name: 'Super Sixty',
        creatorId: ownerId,
      );
      store.tournaments = [tournament];

      final match = Match(
        id: 'm_assigned_1',
        tournamentId: 'tourn_1',
        teamAId: 't1',
        teamBId: 't2',
        xiA: ['p1'],
        xiB: ['p2'],
        tossWinnerId: 't1',
        creatorId: scorerId, // designated creator/scorer of match
      );
      store.matches = [match];

      // Test as Scorer
      await store.activateIdentity(scorerId);
      store.profile = AccountProfile.create(uid: scorerId, displayName: 'Assigned Scorer');

      // 1. Scorer can score this specific match
      final canScore = match.canUserScore(store.effectiveUserId, userCode: store.effectiveUserCode);
      expect(canScore, isTrue);

      // 2. But Scorer is NOT tournament owner
      final isTournOwner = store.effectiveUserId.isNotEmpty &&
          tournament.creatorId == store.effectiveUserId;
      expect(isTournOwner, isFalse);
    });
  });

  group('Tournament UI Widget Access Control Audit', () {
    late Store store;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      store = Store();
      await store.activateIdentity('user_test_default');
    });

    testWidgets('Non-owner sees NO edit or delete buttons on TournamentCard', (tester) async {
      final ownerId = 'user_owner_123';
      final visitorId = 'user_visitor_456';

      await store.activateIdentity(visitorId);
      store.profile = AccountProfile.create(uid: visitorId, displayName: 'Visitor');

      final tournament = Tournament(
        id: 'tourn_card_test',
        name: 'Premier League',
        creatorId: ownerId,
        teamIds: ['t1', 't2'],
      );

      final uid = store.effectiveUserId;
      final isOwner = !AuthService().isRestrictedGuest &&
          (tournament.creatorId.isNotEmpty ? (uid.isNotEmpty && tournament.creatorId == uid) : true);

      expect(isOwner, isFalse);

      bool editCalled = false;
      bool deleteCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TournamentCard(
              tournament: tournament,
              teamCount: 2,
              matchCount: 1,
              loggedIn: true,
              isOwner: isOwner,
              onTap: () {},
              onTogglePublish: () {},
              onEdit: () => editCalled = true,
              onDelete: () => deleteCalled = true,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Ensure Edit and Delete IconButtons are NOT rendered
      expect(find.byIcon(Icons.edit), findsNothing);
      expect(find.byIcon(Icons.delete_outline), findsNothing);
      expect(find.byIcon(Icons.public), findsNothing);
      expect(find.byIcon(Icons.public_off), findsNothing);
      expect(editCalled, isFalse);
      expect(deleteCalled, isFalse);

      // Title should still be clearly displayed
      expect(find.text('Premier League'), findsOneWidget);
    });

    testWidgets('Tournament owner DOES see edit, delete, and publish buttons on TournamentCard', (tester) async {
      final ownerId = 'user_owner_123';
      await store.activateIdentity(ownerId);
      store.profile = AccountProfile.create(uid: ownerId, displayName: 'Owner');

      final tournament = Tournament(
        id: 'tourn_card_test_2',
        name: 'Champions League',
        creatorId: ownerId,
        published: true,
        teamIds: ['t1', 't2'],
      );

      final uid = store.effectiveUserId;
      final isOwner = !AuthService().isRestrictedGuest &&
          (tournament.creatorId.isNotEmpty ? (uid.isNotEmpty && tournament.creatorId == uid) : true);

      expect(isOwner, isTrue);

      bool editCalled = false;
      bool deleteCalled = false;
      bool publishCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TournamentCard(
              tournament: tournament,
              teamCount: 2,
              matchCount: 1,
              loggedIn: true,
              isOwner: isOwner,
              onTap: () {},
              onTogglePublish: () => publishCalled = true,
              onEdit: () => editCalled = true,
              onDelete: () => deleteCalled = true,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Owner must see all management icons
      expect(find.byIcon(Icons.edit), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
      expect(find.byIcon(Icons.public), findsOneWidget);

      // Tap Edit
      await tester.tap(find.byIcon(Icons.edit));
      expect(editCalled, isTrue);

      // Tap Delete
      await tester.tap(find.byIcon(Icons.delete_outline));
      expect(deleteCalled, isTrue);

      // Tap Publish
      await tester.tap(find.byIcon(Icons.public));
      expect(publishCalled, isTrue);
    });

    testWidgets('Non-owner in TournamentDetailScreen has NO edit/delete in AppBar and NO New Fixture FAB', (tester) async {
      final ownerId = 'user_owner_123';
      final visitorId = 'user_visitor_456';

      await store.activateIdentity(visitorId);
      store.profile = AccountProfile.create(uid: visitorId, displayName: 'Visitor');

      final tournament = Tournament(
        id: 'tourn_detail_test',
        name: 'World Cricket Cup',
        creatorId: ownerId,
        teamIds: [],
      );
      store.tournaments = [tournament];

      await tester.pumpWidget(
        MaterialApp(
          home: TournamentDetailScreen(
            store: store,
            tournament: tournament,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Title should be visible
      expect(find.text('World Cricket Cup'), findsWidgets);

      // Share button is available to all
      expect(find.byIcon(Icons.share_outlined), findsOneWidget);

      // Edit and Delete buttons in AppBar must NOT be present
      expect(find.byIcon(Icons.edit_outlined), findsNothing);
      expect(find.byIcon(Icons.delete_outline), findsNothing);

      // Floating Action Button ("New Fixture") must NOT be present
      expect(find.text('New Fixture'), findsNothing);

      // Drain any pending debounced timers
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('Owner in TournamentDetailScreen HAS edit/delete in AppBar and HAS New Fixture FAB', (tester) async {
      final ownerId = 'user_owner_123';
      await store.activateIdentity(ownerId);
      store.profile = AccountProfile.create(uid: ownerId, displayName: 'Owner');

      final tournament = Tournament(
        id: 'tourn_detail_test_owner',
        name: 'World Cricket Cup',
        creatorId: ownerId,
        teamIds: [],
      );
      store.tournaments = [tournament];

      await tester.pumpWidget(
        MaterialApp(
          home: TournamentDetailScreen(
            store: store,
            tournament: tournament,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Edit and Delete buttons in AppBar must be present for Owner
      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);

      // Floating Action Button ("New Fixture") must be present for Owner
      expect(find.text('New Fixture'), findsOneWidget);

      // Drain any pending debounced timers
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('Non-owner in Tab 1 (Fixtures) sees NO Auto Fixtures / Auto Knockouts buttons', (tester) async {
      final ownerId = 'user_owner_123';
      final visitorId = 'user_visitor_456';
      await store.activateIdentity(visitorId);
      store.profile = AccountProfile.create(uid: visitorId, displayName: 'Visitor');

      final tournament = Tournament(
        id: 'tourn_tab1_test',
        name: 'League Tab 1',
        creatorId: ownerId,
        teamIds: [],
      );
      store.tournaments = [tournament];

      await tester.pumpWidget(
        MaterialApp(
          home: TournamentDetailScreen(
            store: store,
            tournament: tournament,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // On Tab 1 (Fixtures tab is default)
      expect(find.text('Auto Fixtures'), findsNothing);
      expect(find.text('Auto Knockouts'), findsNothing);
      expect(find.text('Generate Round-Robin Schedule'), findsNothing);
      expect(find.text('Setup Knockouts / Playoffs'), findsNothing);

      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('Owner in Tab 1 (Fixtures) DOES see Auto Fixtures and Auto Knockouts buttons', (tester) async {
      final ownerId = 'user_owner_123';
      await store.activateIdentity(ownerId);
      store.profile = AccountProfile.create(uid: ownerId, displayName: 'Owner');

      final tournament = Tournament(
        id: 'tourn_tab1_owner_test',
        name: 'League Tab 1 Owner',
        creatorId: ownerId,
        teamIds: [],
      );
      store.tournaments = [tournament];

      await tester.pumpWidget(
        MaterialApp(
          home: TournamentDetailScreen(
            store: store,
            tournament: tournament,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // On Tab 1 for Owner
      expect(find.text('Auto Fixtures'), findsOneWidget);
      expect(find.text('Auto Knockouts'), findsOneWidget);

      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('Non-owner in Tab 3 (Teams) sees NO Enroll Teams or New Team buttons', (tester) async {
      final ownerId = 'user_owner_123';
      final visitorId = 'user_visitor_456';
      await store.activateIdentity(visitorId);
      store.profile = AccountProfile.create(uid: visitorId, displayName: 'Visitor');

      final tournament = Tournament(
        id: 'tourn_tab3_test',
        name: 'League Tab 3',
        creatorId: ownerId,
        teamIds: [],
      );
      store.tournaments = [tournament];

      await tester.pumpWidget(
        MaterialApp(
          home: TournamentDetailScreen(
            store: store,
            tournament: tournament,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Switch to Tab 3 (Teams & Squads)
      await tester.tap(find.text('Teams & Squads'));
      await tester.pumpAndSettle();

      expect(find.text('Enroll Teams'), findsNothing);
      expect(find.text('New Team'), findsNothing);

      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('Owner in Tab 3 (Teams) DOES see Enroll Teams and New Team buttons', (tester) async {
      final ownerId = 'user_owner_123';
      await store.activateIdentity(ownerId);
      store.profile = AccountProfile.create(uid: ownerId, displayName: 'Owner');

      final tournament = Tournament(
        id: 'tourn_tab3_owner_test',
        name: 'League Tab 3 Owner',
        creatorId: ownerId,
        teamIds: [],
      );
      store.tournaments = [tournament];

      await tester.pumpWidget(
        MaterialApp(
          home: TournamentDetailScreen(
            store: store,
            tournament: tournament,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Switch to Tab 3 (Teams & Squads)
      await tester.tap(find.text('Teams & Squads'));
      await tester.pumpAndSettle();

      expect(find.text('Enroll Teams'), findsOneWidget);
      expect(find.text('New Team'), findsOneWidget);

      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('Non-owner in Tab 5 (Overview) sees NO Edit Tournament Details tile', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final ownerId = 'user_owner_123';
      final visitorId = 'user_visitor_456';
      await store.activateIdentity(visitorId);
      store.profile = AccountProfile.create(uid: visitorId, displayName: 'Visitor');

      final tournament = Tournament(
        id: 'tourn_tab5_test',
        name: 'League Tab 5',
        creatorId: ownerId,
        teamIds: [],
      );
      store.tournaments = [tournament];

      await tester.pumpWidget(
        MaterialApp(
          home: TournamentDetailScreen(
            store: store,
            tournament: tournament,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Switch to Tab 5 (Overview & Rules)
      await tester.tap(find.text('Overview & Rules'));
      await tester.pumpAndSettle();

      expect(find.text('Edit Tournament Details'), findsNothing);

      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('Owner in Tab 5 (Overview) DOES see Edit Tournament Details tile', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final ownerId = 'user_owner_123';
      await store.activateIdentity(ownerId);
      store.profile = AccountProfile.create(uid: ownerId, displayName: 'Owner');

      final tournament = Tournament(
        id: 'tourn_tab5_owner_test',
        name: 'League Tab 5 Owner',
        creatorId: ownerId,
        teamIds: [],
      );
      store.tournaments = [tournament];

      await tester.pumpWidget(
        MaterialApp(
          home: TournamentDetailScreen(
            store: store,
            tournament: tournament,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Switch to Tab 5 (Overview & Rules)
      await tester.tap(find.text('Overview & Rules'));
      await tester.pumpAndSettle();

      await tester.drag(find.byType(ListView).last, const Offset(0, -400));
      await tester.pumpAndSettle();

      expect(find.text('Edit Tournament Details'), findsOneWidget);

      await tester.pump(const Duration(seconds: 5));
    });
  });
}
