<?php

use PHPUnit\Framework\TestCase;

class TranslateSQLTest extends TestCase
{
    private YotsubaDB $db;

    protected function setUp(): void
    {
        $pdo = new PDO('sqlite::memory:');
        $ref = new ReflectionClass(YotsubaDB::class);
        $this->db = $ref->newInstanceWithoutConstructor();

        $driverProp = $ref->getProperty('driver');
        $driverProp->setValue($this->db, 'pgsql');

        $pdoProp = $ref->getProperty('pdo');
        $pdoProp->setValue($this->db, $pdo);
    }

    public function testBackticksToDoubleQuotes(): void
    {
        $result = $this->db->translateSQL("SELECT * FROM `posts` WHERE `no` = 1");
        $this->assertStringContainsString('"posts"', $result);
        $this->assertStringContainsString('"no"', $result);
        $this->assertStringNotContainsString('`', $result);
    }

    public function testStripHighPriority(): void
    {
        $result = $this->db->translateSQL("SELECT HIGH_PRIORITY * FROM posts");
        $this->assertStringNotContainsString('HIGH_PRIORITY', $result);
        $this->assertStringContainsString('SELECT', $result);
    }

    public function testStripSqlCache(): void
    {
        $result = $this->db->translateSQL("SELECT SQL_CACHE * FROM posts");
        $this->assertStringNotContainsString('SQL_CACHE', $result);
    }

    public function testStripSqlNoCache(): void
    {
        $result = $this->db->translateSQL("SELECT SQL_NO_CACHE * FROM posts");
        $this->assertStringNotContainsString('SQL_NO_CACHE', $result);
    }

    public function testDateSub(): void
    {
        $result = $this->db->translateSQL("SELECT * FROM posts WHERE time > DATE_SUB(NOW(), INTERVAL 3 DAY)");
        $this->assertStringContainsString("INTERVAL '3 DAY'", $result);
        $this->assertStringNotContainsString('DATE_SUB', $result);
    }

    public function testDateAdd(): void
    {
        $result = $this->db->translateSQL("SELECT * FROM posts WHERE time < DATE_ADD(NOW(), INTERVAL 7 HOUR)");
        $this->assertStringContainsString("INTERVAL '7 HOUR'", $result);
        $this->assertStringNotContainsString('DATE_ADD', $result);
    }

    public function testUnixTimestampWithColumn(): void
    {
        $result = $this->db->translateSQL("SELECT UNIX_TIMESTAMP(created) FROM posts");
        $this->assertStringContainsString('EXTRACT(EPOCH FROM created)::INTEGER', $result);
        $this->assertStringNotContainsString('UNIX_TIMESTAMP', $result);
    }

    public function testUnixTimestampNoArgs(): void
    {
        $result = $this->db->translateSQL("SELECT UNIX_TIMESTAMP()");
        $this->assertStringContainsString('EXTRACT(EPOCH FROM NOW())::INTEGER', $result);
    }

    public function testFromUnixtime(): void
    {
        $result = $this->db->translateSQL("SELECT FROM_UNIXTIME(1234567890)");
        $this->assertStringContainsString('TO_TIMESTAMP(1234567890)', $result);
        $this->assertStringNotContainsString('FROM_UNIXTIME', $result);
    }

    public function testIfExpression(): void
    {
        $result = $this->db->translateSQL("SELECT IF(x > 0, 'yes', 'no') FROM t");
        $this->assertStringContainsString('CASE WHEN', $result);
        $this->assertStringContainsString('THEN', $result);
        $this->assertStringContainsString('ELSE', $result);
        $this->assertStringContainsString('END', $result);
        $this->assertStringNotContainsString('IF(', $result);
    }

    public function testGroupConcat(): void
    {
        $result = $this->db->translateSQL("SELECT GROUP_CONCAT(board) FROM posts");
        $this->assertStringContainsString('STRING_AGG', $result);
        $this->assertStringNotContainsString('GROUP_CONCAT', $result);
    }

    public function testGroupConcatDistinct(): void
    {
        $result = $this->db->translateSQL("SELECT GROUP_CONCAT(DISTINCT board) FROM posts");
        $this->assertStringContainsString('STRING_AGG(DISTINCT', $result);
        $this->assertStringNotContainsString('GROUP_CONCAT', $result);
    }

    public function testLimitOffsetReorder(): void
    {
        $result = $this->db->translateSQL("SELECT * FROM posts LIMIT 10, 20");
        $this->assertStringContainsString('LIMIT 20 OFFSET 10', $result);
        $this->assertStringNotContainsString('LIMIT 10, 20', $result);
    }

    public function testLimitWithoutOffsetUnchanged(): void
    {
        $result = $this->db->translateSQL("SELECT * FROM posts LIMIT 10");
        $this->assertStringContainsString('LIMIT 10', $result);
        $this->assertStringNotContainsString('OFFSET', $result);
    }

    public function testLockTablesBecomesNoOp(): void
    {
        $result = $this->db->translateSQL("LOCK TABLES posts WRITE");
        $this->assertStringContainsString('--', $result);
    }

    public function testUnlockTablesBecomesNoOp(): void
    {
        $result = $this->db->translateSQL("UNLOCK TABLES");
        $this->assertStringContainsString('--', $result);
    }

    public function testShowTablesLike(): void
    {
        $result = $this->db->translateSQL("SHOW TABLES LIKE 'b'");
        $this->assertStringContainsString('pg_tables', $result);
        $this->assertStringContainsString("schemaname = 'public'", $result);
    }

    public function testMysqlModeSqlPassesThrough(): void
    {
        $ref = new ReflectionClass(YotsubaDB::class);
        $db = $ref->newInstanceWithoutConstructor();
        $driverProp = $ref->getProperty('driver');
        $driverProp->setValue($db, 'mysql');
        $pdoProp = $ref->getProperty('pdo');
        $pdoProp->setValue($db, new PDO('sqlite::memory:'));

        $sql = "SELECT * FROM `posts` WHERE no = 1";
        $this->assertSame($sql, $db->translateSQL($sql));
    }

    public function testComplexQueryWithMultipleTranslations(): void
    {
        $sql = "SELECT HIGH_PRIORITY `no`, UNIX_TIMESTAMP(`created`) as ts FROM `posts` WHERE `time` > DATE_SUB(NOW(), INTERVAL 5 MINUTE) LIMIT 10, 25";
        $result = $this->db->translateSQL($sql);

        $this->assertStringNotContainsString('HIGH_PRIORITY', $result);
        $this->assertStringNotContainsString('`', $result);
        $this->assertStringContainsString('EXTRACT(EPOCH FROM', $result);
        $this->assertStringContainsString("INTERVAL '5 MINUTE'", $result);
        $this->assertStringContainsString('LIMIT 25 OFFSET 10', $result);
    }
}
