<?php

declare(strict_types=1);

$root = $argv[1] ?? getcwd();
$root = rtrim($root, DIRECTORY_SEPARATOR);
$mePages = [
    $root . '/resources/themes/dusk/views/user/me.blade.php',
    $root . '/resources/themes/atom/views/user/me.blade.php',
];

foreach ($mePages as $mePage) {
    if (! is_file($mePage)) {
        fwrite(STDERR, "Missing AtomCMS me page: {$mePage}\n");
        exit(1);
    }

    $contents = file_get_contents($mePage);

    if ($contents === false) {
        fwrite(STDERR, "Could not read AtomCMS me page: {$mePage}\n");
        exit(1);
    }

    $contents = str_replace(
        "{{ sprintf(__('User Referrals (%s/%s)'), auth()->user()->referrals->referrals_total ?? 0, setting('referrals_needed')) }}",
        "{{ __('Welkom bij Tjaniekotel') }}",
        $contents
    );

    $contents = str_replace(
        "{{ __('Referral new users and be rewarded by in-game goods') }}",
        "{{ __('Alles is gratis') }}",
        $contents
    );

    $contents = str_replace(
        "{{ __('Here at :hotel we have added a referral system, allowing you to obtain a bonus for every :needed users that registers through your referral link will allow you to claim a reward of :amount diamonds!', ['hotel' => setting('hotel_name'), 'needed' => setting('referrals_needed'), 'amount' => setting('referral_reward_amount')]) }}",
        "{{ __('Alles in Tjaniekotel is gratis. Credits, meubels en speelgeld zijn er om mee te bouwen en plezier te maken, niet om met echt geld te kopen.') }}",
        $contents
    );

    $contents = str_replace(
        "{{ __('Boosting referrals by making own accounts will lead to removal of all progress, currency, inventory and a potential ban') }}",
        "{{ __('Nodig gerust vrienden uit met je link. Iedereen begint met genoeg credits om meteen leuk mee te doen.') }}",
        $contents
    );

    $contents = str_replace(
        "{{ __('Claim your referrals reward!') }}",
        "{{ __('Vrienden uitnodigen') }}",
        $contents
    );

    $contents = str_replace(
        "{{ sprintf(__('You need to refer :needed more users, before being able to claim your reward', ['needed' =>auth()->user()->referralsNeeded() ?? 0]),auth()->user()->referrals->referrals_total ?? 0) }}",
        "{{ __('Deel je link met vrienden. Er is geen betaling nodig, alles is gratis.') }}",
        $contents
    );

    $contents = preg_replace(
        '/\n\s*@if \(auth\(\)->user\(\)->referrals\?->referrals_total >= \(int\) setting\(\'referrals_needed\'\)\).*?@endif/s',
        "\n                <button disabled class=\"mt-2 w-full rounded bg-[#171a23] p-2 text-white\">\n                    {{ __('Deel je link met vrienden. Er is geen betaling nodig, alles is gratis.') }}\n                </button>",
        $contents,
        1,
        $count
    );

    if ($contents === null || $count !== 1) {
        fwrite(STDERR, "Could not replace referral reward button block in {$mePage}\n");
        exit(1);
    }

    file_put_contents($mePage, $contents);
}

$settingsSeeder = $root . '/database/seeders/WebsiteSettingsSeeder.php';
$setupCommand = $root . '/app/Console/Commands/AtomSetupCommand.php';

foreach ([$settingsSeeder, $setupCommand] as $path) {
    if (! is_file($path)) {
        fwrite(STDERR, "Missing AtomCMS credits source: {$path}\n");
        exit(1);
    }
}

$settings = file_get_contents($settingsSeeder);
$settings = str_replace(
    "'key' => 'start_credits',\n                'value' => '5000',",
    "'key' => 'start_credits',\n                'value' => '100000',",
    $settings
);
file_put_contents($settingsSeeder, $settings);

$setup = file_get_contents($setupCommand);
$setup = str_replace(
    "Enter the amount of credits new users should start with: (default is 5000)",
    "Enter the amount of credits new users should start with: (default is 100000)",
    $setup
);
$setup = str_replace(
    "\$startDuckets = \$this->ask('Enter the amount of credits new users should start with: (default is 100000)');",
    "\$startDuckets = \$this->ask('Enter the amount of duckets new users should start with: (default is 5000)');",
    $setup
);
$setup = str_replace(
    "empty(\$startCredits) ? '5000' : \$startCredits",
    "empty(\$startCredits) ? '100000' : \$startCredits",
    $setup
);
file_put_contents($setupCommand, $setup);
