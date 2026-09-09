<?php

/**
 * Parse and validate a user-supplied source attachment filename.
 *
 * The returned filename never contains a path and does not include the
 * extension. The extension is normalized to lower case and includes its dot.
 */
function source_attachment_metadata(string $originalName, string $allowedExtensions): ?array
{
    $name = str_replace(["\0", '\\'], ['', '/'], trim($originalName));
    $name = basename($name);
    $name = preg_replace('/[\x00-\x1F\x7F]/u', '', $name) ?? '';
    $extension = strtolower(pathinfo($name, PATHINFO_EXTENSION));

    $allowed = array_values(array_filter(array_map(
        static fn(string $value): string => strtolower(ltrim(trim($value), '.')),
        explode(',', $allowedExtensions)
    )));

    if ($name === '' || $extension === '' || !in_array($extension, $allowed, true)) {
        return null;
    }

    $filename = pathinfo($name, PATHINFO_FILENAME);
    if ($filename === '') {
        $filename = 'source';
    }

    // Keep metadata within the database column limits.
    $filename = mb_substr($filename, 0, 255);

    return [
        'filename' => $filename,
        'ext' => '.' . $extension,
        'display_name' => $filename . '.' . $extension,
    ];
}

function source_attachment_url(string $board, int $postNo, string $displayName): string
{
    return '/source/' . rawurlencode($board) . '/' . $postNo . '/' . rawurlencode($displayName);
}

/**
 * Normalize PDO's driver-specific binary result into a bindable value.
 */
function source_attachment_data($value): ?string
{
    if ($value === null) {
        return null;
    }
    if (is_resource($value)) {
        $value = stream_get_contents($value);
    }
    return is_string($value) ? $value : '';
}
