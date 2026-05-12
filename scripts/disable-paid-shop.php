<?php

declare(strict_types=1);

$root = rtrim($argv[1] ?? getcwd(), DIRECTORY_SEPARATOR);

function pathFromRoot(string $root, string $path): string
{
    return $root . DIRECTORY_SEPARATOR . str_replace('/', DIRECTORY_SEPARATOR, $path);
}

function readFileOrFail(string $path): string
{
    $contents = @file_get_contents($path);

    if ($contents === false) {
        throw new RuntimeException("Could not read {$path}");
    }

    return $contents;
}

function writeIfChanged(string $path, string $contents): void
{
    if (readFileOrFail($path) !== $contents) {
        file_put_contents($path, $contents);
        echo "Updated {$path}\n";
    }
}

function replacePattern(string $path, string $pattern, string $replacement, string $label): void
{
    $contents = readFileOrFail($path);
    $updated = preg_replace($pattern, $replacement, $contents, 1, $count);

    if ($updated === null) {
        throw new RuntimeException("Invalid regex while patching {$label}");
    }

    if ($count > 0) {
        writeIfChanged($path, $updated);
        return;
    }

    echo "Already patched or not found: {$label}\n";
}

function replaceExact(string $path, string $search, string $replacement, string $label): void
{
    $contents = readFileOrFail($path);

    if (! str_contains($contents, $search)) {
        echo "Already patched or not found: {$label}\n";
        return;
    }

    writeIfChanged($path, str_replace($search, $replacement, $contents));
}

$routes = pathFromRoot($root, 'routes/web.php');

replaceExact($routes, "use App\\Http\\Controllers\\Shop\\PaypalController;\n", '', 'PayPal controller import');
replaceExact($routes, "use App\\Http\\Controllers\\Shop\\ShopController;\n", '', 'Shop controller import');
replaceExact($routes, "use App\\Http\\Controllers\\Shop\\ShopVoucherController;\n", '', 'Shop voucher controller import');

replacePattern(
    $routes,
    '/\n\s*\/\/ Shop routes\s*Route::prefix\(\'shop\'\)->group\(function \(\) \{\s*Route::get\(\'\/\{category:slug\?\}\', ShopController::class\)->name\(\'shop\.index\'\);\s*Route::post\(\'\/purchase\/\{package\}\', \[ShopController::class, \'purchase\'\]\)->name\(\'shop\.buy\'\);\s*Route::post\(\'\/voucher\', ShopVoucherController::class\)->name\(\'shop\.use-voucher\'\);\s*\}\);/s',
    "\n        // Real-money shop routes removed for Tjaniekotel.\n        // Gameplay currencies and rare values remain available.",
    'public shop routes',
);

replacePattern(
    $routes,
    '/\n\s*\/\/ Paypal routes\s*Route::controller\(PayPalController::class\)->prefix\(\'paypal\'\)->group\(function\(\) \{\s*Route::get\(\'\/process-transaction\', \'process\'\)->name\(\'paypal\.process-transaction\'\);\s*Route::get\(\'\/successful-transaction\', \'successful\'\)->name\(\'paypal\.successful-transaction\'\);\s*Route::get\(\'\/cancelled-transaction\', \'cancelled\'\)->name\(\'paypal\.cancelled-transaction\'\);\s*\}\);/s',
    "\n        // PayPal top-up and transaction callback routes removed for Tjaniekotel.",
    'PayPal routes',
);

replacePattern(
    pathFromRoot($root, 'resources/themes/dusk/views/components/navigation/navigation-menu.blade.php'),
    '/\n\s*<a href="\{\{ route\(\'shop\.index\'\) \}\}" class="flex flex-col gap-1 items-center transition ease-in-out hover:text-\[#ac93da\]">\s*<img class="icon" src="\{\{ asset\(\'\/assets\/images\/dusk\/store_icon\.png\'\) \}\}" alt="community icon">\s*Store\s*<\/a>/s',
    "\n",
    'Dusk Store navigation item',
);

replacePattern(
    pathFromRoot($root, 'resources/themes/atom/views/components/navigation/navigation-menu.blade.php'),
    '/\n\s*<a data-turbolinks="false" href="\{\{ route\(\'shop\.index\'\) \}\}"\s*class="nav-item dark:text-gray-200 \{\{ request\(\)->routeIs\(\'shop\.\*\'\) \? \'md:border-b-4 md:border-b-\[#eeb425\]\' : \'\' \}\}">\s*<i class="navigation-icon mr-1 hidden lg:inline-flex shop"><\/i>\s*\{\{ __\(\'Shop\'\) \}\}\s*<\/a>/s',
    "\n",
    'Atom Shop navigation item',
);

replacePattern(
    pathFromRoot($root, 'resources/themes/dusk/views/components/navigation/mobile-navigation-menu.blade.php'),
    '/\n\s*<a href="" class="transition ease-in-out hover:text-\[#ac93da\]">\s*Store\s*<\/a>/s',
    "\n",
    'Dusk mobile Store navigation item',
);

replaceExact(
    pathFromRoot($root, 'resources/themes/dusk/views/components/footer.blade.php'),
    'Automatic language registration, rooms page, profile page fixes & Paypal shop contributions',
    'Automatic language registration, rooms page, profile page fixes & community improvements',
    'Dusk footer PayPal shop credit text',
);

$disabledWidget = <<<'PHP'
<?php

namespace App\Filament\Resources\DashboardResource\Widgets;

use Filament\Widgets\Widget;

class LatestOrders extends Widget
{
    protected static bool $isDiscovered = false;

    public static function canView(): bool
    {
        return false;
    }
}
PHP;

writeIfChanged(pathFromRoot($root, 'app/Filament/Resources/DashboardResource/Widgets/LatestOrders.php'), $disabledWidget);

$disabledChart = <<<'PHP'
<?php

namespace App\Filament\Resources\DashboardResource\Widgets;

use Filament\Widgets\Widget;

class OrdersAggregateChart extends Widget
{
    protected static bool $isDiscovered = false;

    public static function canView(): bool
    {
        return false;
    }
}
PHP;

writeIfChanged(pathFromRoot($root, 'app/Filament/Resources/DashboardResource/Widgets/OrdersAggregateChart.php'), $disabledChart);

echo "Paid shop, PayPal, voucher, top-up, and shop purchase widgets are disabled. Existing gameplay currencies and data were not changed.\n";
