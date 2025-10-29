import 'package:test/test.dart';
import 'package:ess_pdf_processor/parser/shooter_list_text_parser.dart';

void main() {
	group('parseShooterListFromText', () {
		test('parses simple lines with class tokens', () {
			final input = '1 John Doe A\n2 Jane Smith GM\n3 Bob';
			final m = parseShooterListFromText(input);
			expect(m.length, equals(3));
			expect(m[1], equals('A'));
			expect(m[2], equals('GM'));
			expect(m[3], equals(''));
		});

		test('handles CRLF and extra whitespace', () {
			final input = '4 Alice CRLF\r\n5   Bob   B   \n\n  \n6Charlie C';
			final m = parseShooterListFromText(input);
			expect(m[4], equals(''));
			expect(m[5], equals('B'));
			expect(m[6], equals('C'));
		});

		test('prefers non-empty class when duplicate entries exist', () {
			final input = '7 Old\n7 New A';
			final m = parseShooterListFromText(input);
			expect(m[7], equals('A'));
		});

		test('ignores lines without leading numbers', () {
			final input = 'Name Only A\n8 Valid B';
			final m = parseShooterListFromText(input);
			expect(m.containsKey(8), isTrue);
			expect(m.length, equals(1));
		});
	});
}

