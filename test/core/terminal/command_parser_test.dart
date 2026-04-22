import 'package:bolan/core/terminal/command_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('extractCommandNames', () {
    test('simple command', () {
      expect(extractCommandNames('ls -la'), ['ls']);
    });

    test('pipeline', () {
      expect(extractCommandNames('ls | grep foo'), ['ls', 'grep']);
    });

    test('chain with &&', () {
      expect(extractCommandNames('echo hello && mysql -u root'),
          ['echo', 'mysql']);
    });

    test('chain with ||', () {
      expect(extractCommandNames('false || ssh user@host'),
          ['false', 'ssh']);
    });

    test('chain with ;', () {
      expect(extractCommandNames('cd /tmp; python3'), ['cd', 'python3']);
    });

    test('quoted string with && inside', () {
      expect(
          extractCommandNames('echo " && mysql -u root" && sleep 2'),
          ['echo', 'sleep']);
    });

    test('single-quoted string with special chars', () {
      expect(
          extractCommandNames("echo '&& ssh || rm' && ls"),
          ['echo', 'ls']);
    });

    test('sudo prefix is stripped', () {
      expect(extractCommandNames('sudo su -'), ['su']);
    });

    test('sudo with flags', () {
      expect(extractCommandNames('sudo -u root mysql'), ['mysql']);
    });

    test('env prefix is stripped', () {
      expect(extractCommandNames('env FOO=bar python3'), ['python3']);
    });

    test('env var assignment prefix', () {
      expect(extractCommandNames('RAILS_ENV=production rails console'),
          ['rails']);
    });

    test('command with path', () {
      expect(extractCommandNames('/usr/bin/ssh user@host'), ['ssh']);
    });

    test('empty string', () {
      expect(extractCommandNames(''), <String>[]);
    });

    test('mixed operators', () {
      expect(
          extractCommandNames('make build && ./deploy.sh || echo failed'),
          ['make', 'deploy.sh', 'echo']);
    });

    test('escaped quote', () {
      expect(
          extractCommandNames(r'echo "hello \"world\"" && ls'),
          ['echo', 'ls']);
    });

    test('nohup prefix', () {
      expect(extractCommandNames('nohup node server.js'), ['node']);
    });

    test('multiple prefixes', () {
      expect(extractCommandNames('sudo env NODE_ENV=prod node'),
          ['node']);
    });
  });
}
