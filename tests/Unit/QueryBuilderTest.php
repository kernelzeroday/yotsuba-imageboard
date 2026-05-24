<?php

use PHPUnit\Framework\TestCase;

class QueryBuilderTest extends TestCase
{
    private function makeDb(string $driver): YotsubaDB
    {
        $ref = new ReflectionClass(YotsubaDB::class);
        $db = $ref->newInstanceWithoutConstructor();
        $ref->getProperty('driver')->setValue($db, $driver);
        $ref->getProperty('pdo')->setValue($db, new PDO('sqlite::memory:'));
        $ref->getProperty('lockLevel')->setValue($db, 0);
        return $db;
    }

    // buildSelect

    public function testBuildSelectBasic(): void
    {
        $db = $this->makeDb('mysql');
        [$sql, $params] = $db->buildSelect('posts', ['*']);
        $this->assertSame('SELECT * FROM `posts`', $sql);
        $this->assertEmpty($params);
    }

    public function testBuildSelectWithColumns(): void
    {
        $db = $this->makeDb('mysql');
        [$sql, $params] = $db->buildSelect('posts', ['no', 'com', 'name']);
        $this->assertSame('SELECT `no`, `com`, `name` FROM `posts`', $sql);
    }

    public function testBuildSelectWithWhere(): void
    {
        $db = $this->makeDb('mysql');
        [$sql, $params] = $db->buildSelect('posts', ['*'], ['board' => 'g', 'active' => 1]);
        $this->assertStringContainsString('WHERE', $sql);
        $this->assertStringContainsString('`board` = ?', $sql);
        $this->assertStringContainsString('`active` = ?', $sql);
        $this->assertSame(['g', 1], $params);
    }

    public function testBuildSelectWithOperators(): void
    {
        $db = $this->makeDb('mysql');
        [$sql, $params] = $db->buildSelect('posts', ['*'], ['no >=' => 100, 'no <=' => 200]);
        $this->assertStringContainsString('`no` >= ?', $sql);
        $this->assertStringContainsString('`no` <= ?', $sql);
        $this->assertSame([100, 200], $params);
    }

    public function testBuildSelectWithLikeOperator(): void
    {
        $db = $this->makeDb('mysql');
        [$sql, $params] = $db->buildSelect('posts', ['*'], ['com LIKE' => '%test%']);
        $this->assertStringContainsString('`com` LIKE ?', $sql);
        $this->assertSame(['%test%'], $params);
    }

    public function testBuildSelectWithOrder(): void
    {
        $db = $this->makeDb('mysql');
        [$sql, $params] = $db->buildSelect('posts', ['*'], [], ['no' => 'DESC']);
        $this->assertStringContainsString('ORDER BY `no` DESC', $sql);
    }

    public function testBuildSelectWithLimit(): void
    {
        $db = $this->makeDb('mysql');
        [$sql, $params] = $db->buildSelect('posts', ['*'], [], [], 10);
        $this->assertStringContainsString('LIMIT 10', $sql);
        $this->assertStringNotContainsString('OFFSET', $sql);
    }

    public function testBuildSelectWithLimitAndOffset(): void
    {
        $db = $this->makeDb('mysql');
        [$sql, $params] = $db->buildSelect('posts', ['*'], [], [], 10, 20);
        $this->assertStringContainsString('LIMIT 10', $sql);
        $this->assertStringContainsString('OFFSET 20', $sql);
    }

    public function testBuildSelectPgsqlQuoting(): void
    {
        $db = $this->makeDb('pgsql');
        [$sql, $params] = $db->buildSelect('int', ['no', 'com'], ['board' => 'int']);
        $this->assertStringContainsString('"int"', $sql);
        $this->assertStringContainsString('"no"', $sql);
        $this->assertStringNotContainsString('`', $sql);
    }

    // buildInsert

    public function testBuildInsert(): void
    {
        $db = $this->makeDb('mysql');
        [$sql, $params] = $db->buildInsert('posts', ['com' => 'hello', 'name' => 'Anonymous']);
        $this->assertStringContainsString('INSERT INTO `posts`', $sql);
        $this->assertStringContainsString('`com`', $sql);
        $this->assertStringContainsString('`name`', $sql);
        $this->assertStringContainsString('?, ?', $sql);
        $this->assertSame(['hello', 'Anonymous'], $params);
    }

    // buildUpdate

    public function testBuildUpdate(): void
    {
        $db = $this->makeDb('mysql');
        [$sql, $params] = $db->buildUpdate('posts', ['com' => 'edited'], ['no' => 123]);
        $this->assertStringContainsString('UPDATE `posts` SET `com` = ?', $sql);
        $this->assertStringContainsString('WHERE `no` = ?', $sql);
        $this->assertSame(['edited', 123], $params);
    }

    public function testBuildUpdateMultipleFields(): void
    {
        $db = $this->makeDb('mysql');
        [$sql, $params] = $db->buildUpdate('posts', ['com' => 'x', 'name' => 'y'], ['no' => 1, 'board' => 'b']);
        $this->assertCount(4, $params);
        $this->assertSame(['x', 'y', 1, 'b'], $params);
    }

    // buildDelete

    public function testBuildDelete(): void
    {
        $db = $this->makeDb('mysql');
        [$sql, $params] = $db->buildDelete('posts', ['no' => 123]);
        $this->assertStringContainsString('DELETE FROM `posts` WHERE `no` = ?', $sql);
        $this->assertSame([123], $params);
    }

    public function testBuildDeleteMultipleConditions(): void
    {
        $db = $this->makeDb('mysql');
        [$sql, $params] = $db->buildDelete('posts', ['no' => 123, 'board' => 'b']);
        $this->assertStringContainsString('`no` = ?', $sql);
        $this->assertStringContainsString('`board` = ?', $sql);
        $this->assertSame([123, 'b'], $params);
    }

    // buildUpsert

    public function testBuildUpsertMysql(): void
    {
        $db = $this->makeDb('mysql');
        [$sql, $params] = $db->buildUpsert('md5', ['md5' => 'abc', 'count' => 1], 'md5', ['count' => 'count + 1']);
        $this->assertStringContainsString('INSERT INTO', $sql);
        $this->assertStringContainsString('ON DUPLICATE KEY UPDATE', $sql);
        $this->assertStringContainsString('count + 1', $sql);
    }

    public function testBuildUpsertPgsql(): void
    {
        $db = $this->makeDb('pgsql');
        [$sql, $params] = $db->buildUpsert('md5', ['md5' => 'abc', 'count' => 1], 'md5', ['count' => 'EXCLUDED.count + 1']);
        $this->assertStringContainsString('INSERT INTO', $sql);
        $this->assertStringContainsString('ON CONFLICT ("md5") DO UPDATE SET', $sql);
        $this->assertStringContainsString('EXCLUDED.count + 1', $sql);
    }

    public function testBuildUpsertMultipleConflictKeys(): void
    {
        $db = $this->makeDb('pgsql');
        [$sql, $params] = $db->buildUpsert('t', ['a' => 1, 'b' => 2], ['a', 'b'], ['b' => 'EXCLUDED.b']);
        $this->assertStringContainsString('ON CONFLICT ("a", "b")', $sql);
    }
}
