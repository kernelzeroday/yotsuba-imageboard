<?php

use PHPUnit\Framework\TestCase;

class IdentifierQuotingTest extends TestCase
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

    public function testMysqlBackticks(): void
    {
        $db = $this->makeDb('mysql');
        $this->assertSame('`posts`', $db->qi('posts'));
        $this->assertSame('`int`', $db->qi('int'));
    }

    public function testPgsqlDoubleQuotes(): void
    {
        $db = $this->makeDb('pgsql');
        $this->assertSame('"posts"', $db->qi('posts'));
        $this->assertSame('"int"', $db->qi('int'));
    }

    public function testReservedWordBoards(): void
    {
        $db = $this->makeDb('pgsql');
        $reserved = ['int', 'out', 'test', 'all', 'user', 'order', 'group', 'select'];
        foreach ($reserved as $word) {
            $this->assertSame('"' . $word . '"', $db->qi($word));
        }
    }

    public function testStripsExistingQuotes(): void
    {
        $db = $this->makeDb('pgsql');
        $this->assertSame('"posts"', $db->qi('`posts`'));
        $this->assertSame('"posts"', $db->qi('"posts"'));
    }

    public function testQiIsShorthandForQuoteIdentifier(): void
    {
        $db = $this->makeDb('mysql');
        $this->assertSame($db->quoteIdentifier('posts'), $db->qi('posts'));
    }
}
