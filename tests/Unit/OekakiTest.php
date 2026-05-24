<?php

use PHPUnit\Framework\TestCase;

require_once __DIR__ . '/../../lib/oekaki.php';

class OekakiTest extends TestCase
{
    public function testFormatInfoZeroTime(): void
    {
        $this->assertSame('', oekaki_format_info(0, null, null));
    }

    public function testFormatInfoNegativeTime(): void
    {
        $this->assertSame('', oekaki_format_info(-1, null, null));
    }

    public function testFormatInfoExcessiveTime(): void
    {
        $this->assertSame('', oekaki_format_info(5184001, null, null));
    }

    public function testFormatInfoSeconds(): void
    {
        $result = oekaki_format_info(30, null, null);
        $this->assertStringContainsString('30s', $result);
        $this->assertStringContainsString('Oekaki Post', $result);
    }

    public function testFormatInfoMinutes(): void
    {
        $result = oekaki_format_info(300, null, null);
        $this->assertStringContainsString('5m', $result);
    }

    public function testFormatInfoHoursAndMinutes(): void
    {
        $result = oekaki_format_info(3661, null, null);
        $this->assertStringContainsString('1h 1m', $result);
    }

    public function testFormatInfoWithReplay(): void
    {
        $result = oekaki_format_info(60, 12345, null);
        $this->assertStringContainsString('Replay:', $result);
        $this->assertStringContainsString('oeReplay(12345)', $result);
    }

    public function testFormatInfoWithSourcePid(): void
    {
        $result = oekaki_format_info(60, null, 42);
        $this->assertStringContainsString('Source:', $result);
        $this->assertStringContainsString('&gt;&gt;42', $result);
    }

    public function testFormatInfoReplayHiddenWhenSourceSet(): void
    {
        $result = oekaki_format_info(60, 12345, 42);
        $this->assertStringNotContainsString('Replay:', $result);
        $this->assertStringContainsString('Source:', $result);
    }
}
