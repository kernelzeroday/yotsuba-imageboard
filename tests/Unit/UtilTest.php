<?php

use PHPUnit\Framework\TestCase;

require_once __DIR__ . '/../../lib/util.php';

class UtilTest extends TestCase
{
    // cidrtest

    public function testCidrtestMatchesSubnet(): void
    {
        $ip = ip2long('192.168.1.100');
        $this->assertTrue(cidrtest($ip, '192.168.1.0/24'));
    }

    public function testCidrtestRejectsOutsideSubnet(): void
    {
        $ip = ip2long('10.0.0.1');
        $this->assertFalse(cidrtest($ip, '192.168.1.0/24'));
    }

    public function testCidrtestMatchesSingleHost(): void
    {
        $ip = ip2long('8.8.8.8');
        $this->assertTrue(cidrtest($ip, '8.8.8.8/32'));
    }

    public function testCidrtestInvalidMask(): void
    {
        $ip = ip2long('10.0.0.1');
        $this->assertFalse(cidrtest($ip, '10.0.0.0/0'));
    }

    public function testCidrtestMatchesWideSubnet(): void
    {
        $ip = ip2long('10.255.255.255');
        $this->assertTrue(cidrtest($ip, '10.0.0.0/8'));
    }

    // sec2hms

    public function testSec2hmsMinutes(): void
    {
        $this->assertSame('5 minutes', sec2hms(300));
    }

    public function testSec2hmsHoursAndMinutes(): void
    {
        $result = sec2hms(3661);
        $this->assertStringContainsString('1 hour', $result);
        $this->assertStringContainsString('1 minute', $result);
    }

    public function testSec2hmsPluralHours(): void
    {
        $result = sec2hms(7200);
        $this->assertStringContainsString('2 hours', $result);
    }

    public function testSec2hmsWithSeconds(): void
    {
        $result = sec2hms(65, false, true);
        $this->assertStringContainsString('1 minute', $result);
        $this->assertStringContainsString('5 seconds', $result);
    }

    public function testSec2hmsPaddedTime(): void
    {
        $result = sec2hms(3661, true);
        $this->assertStringContainsString('01 hour', $result);
        $this->assertStringContainsString('01 minute', $result);
    }

    // country_code_to_name

    public function testCountryCodeToNameKnown(): void
    {
        $this->assertSame('United States', country_code_to_name('US'));
        $this->assertSame('Japan', country_code_to_name('JP'));
        $this->assertSame('Germany', country_code_to_name('DE'));
    }

    public function testCountryCodeToNameUnknown(): void
    {
        $this->assertSame('Unknown', country_code_to_name('ZZ'));
    }

    // L class

    public function testLDomainNwsBoard(): void
    {
        $this->assertSame('4chan.org', L::d('b'));
        $this->assertSame('4chan.org', L::d('pol'));
    }

    public function testLDomainSwsBoard(): void
    {
        $this->assertSame('4chan.org', L::d('g'));
        $this->assertSame('4chan.org', L::d('a'));
    }

    public function testLBoardUrl(): void
    {
        $this->assertSame('/b/', L::board_url('b'));
        $this->assertSame('/g/', L::board_url('g'));
    }

    // troll_countries

    public function testTrollCountriesReturnsArray(): void
    {
        $countries = troll_countries();
        $this->assertIsArray($countries);
        $this->assertArrayHasKey('KN', $countries);
        $this->assertSame('Kekistani', $countries['KN']);
    }

    // find_ipxff_in

    public function testFindIpxffInMatchesIp(): void
    {
        $ip = ip2long('192.168.1.50');
        $xff = ip2long('10.0.0.1');
        $this->assertTrue(find_ipxff_in($ip, $xff, ['192.168.1.0/24']));
    }

    public function testFindIpxffInMatchesXff(): void
    {
        $ip = ip2long('10.0.0.1');
        $xff = ip2long('192.168.1.50');
        $this->assertTrue(find_ipxff_in($ip, $xff, ['192.168.1.0/24']));
    }

    public function testFindIpxffInNoMatch(): void
    {
        $ip = ip2long('10.0.0.1');
        $xff = ip2long('10.0.0.2');
        $this->assertFalse(find_ipxff_in($ip, $xff, ['192.168.1.0/24']));
    }

    public function testFindIpxffInSkipsComments(): void
    {
        $ip = ip2long('192.168.1.50');
        $xff = ip2long('10.0.0.1');
        $this->assertFalse(find_ipxff_in($ip, $xff, ['# 192.168.1.0/24']));
    }
}
