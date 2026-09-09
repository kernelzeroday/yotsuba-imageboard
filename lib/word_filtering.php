<?php

function word_filter_timing(): string
{
    $timing = defined('WORD_FILT_TIMING') ? strtolower((string)WORD_FILT_TIMING) : 'store';
    return in_array($timing, ['store', 'render'], true) ? $timing : 'store';
}

function word_filter_should_load(): bool
{
    return defined('WORD_FILT') && WORD_FILT;
}

function word_filter_for_store(string $text, string $type): string
{
    global $word_filters_enabled;

    if (word_filter_should_load()
        && word_filter_timing() === 'store'
        && $word_filters_enabled
        && function_exists('word_filter')) {
        return word_filter($text, $type);
    }

    return $text;
}

function word_filter_for_render(string $text, string $type): string
{
    global $word_filters_enabled;

    if (word_filter_should_load()
        && word_filter_timing() === 'render'
        && $word_filters_enabled
        && function_exists('word_filter')) {
        return word_filter($text, $type);
    }

    return $text;
}

function word_filter_poster_name_for_render(string $name, string $anonymousName): string
{
    $separator = '</span> <span class="postertrip">';
    $parts = explode($separator, $name, 2);
    if ($parts[0] === $anonymousName) {
        return $name;
    }

    $parts[0] = word_filter_for_render($parts[0], 'name');
    return count($parts) === 2 ? $parts[0] . $separator . $parts[1] : $parts[0];
}
