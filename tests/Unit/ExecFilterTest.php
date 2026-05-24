<?php

use PHPUnit\Framework\TestCase;

class ExecFilterTest extends TestCase
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

    public function testMysqlSetCommandsPassThrough(): void
    {
        $db = $this->makeDb('mysql');
        $pdo = $db->getPdo();
        $pdo->exec("CREATE TABLE t (id INTEGER)");
        $result = $db->exec("INSERT INTO t VALUES (1)");
        $this->assertSame(1, $result);
    }

    public function testPgsqlSkipsReadBufferSize(): void
    {
        $db = $this->makeDb('pgsql');
        $result = $db->exec("SET read_buffer_size=1048576");
        $this->assertSame(0, $result);
    }

    public function testPgsqlSkipsSortBufferSize(): void
    {
        $db = $this->makeDb('pgsql');
        $result = $db->exec("SET sort_buffer_size=262144");
        $this->assertSame(0, $result);
    }

    public function testPgsqlSkipsNetWriteTimeout(): void
    {
        $db = $this->makeDb('pgsql');
        $result = $db->exec("SET net_write_timeout=60");
        $this->assertSame(0, $result);
    }

    public function testPgsqlSkipsWaitTimeout(): void
    {
        $db = $this->makeDb('pgsql');
        $result = $db->exec("SET wait_timeout=28800");
        $this->assertSame(0, $result);
    }

    public function testPgsqlSkipsSqlMode(): void
    {
        $db = $this->makeDb('pgsql');
        $result = $db->exec("SET sql_mode='STRICT_TRANS_TABLES'");
        $this->assertSame(0, $result);
    }

    public function testPgsqlDoesNotSkipValidStatements(): void
    {
        $db = $this->makeDb('pgsql');
        $pdo = $db->getPdo();
        $pdo->exec("CREATE TABLE t (id INTEGER)");
        $result = $db->exec("INSERT INTO t VALUES (1)");
        $this->assertSame(1, $result);
    }
}
