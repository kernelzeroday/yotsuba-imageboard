<?php

use PHPUnit\Framework\TestCase;

class DialectHelpersTest extends TestCase
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

    // dateInterval

    public function testDateIntervalMysql(): void
    {
        $db = $this->makeDb('mysql');
        $this->assertSame('DATE_SUB(NOW(), INTERVAL 3 DAY)', $db->dateInterval('NOW()', 3, 'DAY'));
    }

    public function testDateIntervalPgsql(): void
    {
        $db = $this->makeDb('pgsql');
        $this->assertSame("NOW() - INTERVAL '3 DAY'", $db->dateInterval('NOW()', 3, 'DAY'));
    }

    public function testDateIntervalUnitNormalization(): void
    {
        $db = $this->makeDb('pgsql');
        $result = $db->dateInterval('NOW()', 5, 'minute');
        $this->assertSame("NOW() - INTERVAL '5 MINUTE'", $result);
    }

    // dateAdd

    public function testDateAddMysql(): void
    {
        $db = $this->makeDb('mysql');
        $this->assertSame('DATE_ADD(NOW(), INTERVAL 7 HOUR)', $db->dateAdd('NOW()', 7, 'HOUR'));
    }

    public function testDateAddPgsql(): void
    {
        $db = $this->makeDb('pgsql');
        $this->assertSame("NOW() + INTERVAL '7 HOUR'", $db->dateAdd('NOW()', 7, 'HOUR'));
    }

    // unixTimestamp

    public function testUnixTimestampWithColMysql(): void
    {
        $db = $this->makeDb('mysql');
        $this->assertSame('UNIX_TIMESTAMP(created)', $db->unixTimestamp('created'));
    }

    public function testUnixTimestampWithColPgsql(): void
    {
        $db = $this->makeDb('pgsql');
        $this->assertSame('EXTRACT(EPOCH FROM created)::INTEGER', $db->unixTimestamp('created'));
    }

    public function testUnixTimestampNoArgsMysql(): void
    {
        $db = $this->makeDb('mysql');
        $this->assertSame('UNIX_TIMESTAMP()', $db->unixTimestamp());
    }

    public function testUnixTimestampNoArgsPgsql(): void
    {
        $db = $this->makeDb('pgsql');
        $this->assertSame('EXTRACT(EPOCH FROM NOW())::INTEGER', $db->unixTimestamp());
    }

    // fromUnixtime

    public function testFromUnixtimeMysql(): void
    {
        $db = $this->makeDb('mysql');
        $this->assertSame('FROM_UNIXTIME(1234)', $db->fromUnixtime('1234'));
    }

    public function testFromUnixtimePgsql(): void
    {
        $db = $this->makeDb('pgsql');
        $this->assertSame('TO_TIMESTAMP(1234)', $db->fromUnixtime('1234'));
    }

    // ifExpr

    public function testIfExprMysql(): void
    {
        $db = $this->makeDb('mysql');
        $this->assertSame("IF(x > 0, 'yes', 'no')", $db->ifExpr("x > 0", "'yes'", "'no'"));
    }

    public function testIfExprPgsql(): void
    {
        $db = $this->makeDb('pgsql');
        $this->assertSame("CASE WHEN x > 0 THEN 'yes' ELSE 'no' END", $db->ifExpr("x > 0", "'yes'", "'no'"));
    }

    // groupConcat

    public function testGroupConcatMysql(): void
    {
        $db = $this->makeDb('mysql');
        $this->assertSame('GROUP_CONCAT(board)', $db->groupConcat('board'));
    }

    public function testGroupConcatPgsql(): void
    {
        $db = $this->makeDb('pgsql');
        $this->assertSame("STRING_AGG(board::TEXT, ',')", $db->groupConcat('board'));
    }

    public function testGroupConcatDistinctMysql(): void
    {
        $db = $this->makeDb('mysql');
        $this->assertSame('GROUP_CONCAT(DISTINCT board)', $db->groupConcatDistinct('board'));
    }

    public function testGroupConcatDistinctPgsql(): void
    {
        $db = $this->makeDb('pgsql');
        $this->assertSame("STRING_AGG(DISTINCT board::TEXT, ',')", $db->groupConcatDistinct('board'));
    }

    // concat

    public function testConcatMysql(): void
    {
        $db = $this->makeDb('mysql');
        $this->assertSame("CONCAT('a', 'b', 'c')", $db->concat("'a'", "'b'", "'c'"));
    }

    public function testConcatPgsql(): void
    {
        $db = $this->makeDb('pgsql');
        $this->assertSame("'a' || 'b' || 'c'", $db->concat("'a'", "'b'", "'c'"));
    }

    // now

    public function testNow(): void
    {
        $db = $this->makeDb('mysql');
        $this->assertSame('NOW()', $db->now());
        $db = $this->makeDb('pgsql');
        $this->assertSame('NOW()', $db->now());
    }
}
