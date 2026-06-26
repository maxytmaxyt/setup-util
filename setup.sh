#!/bin/bash

# Ordner festlegen
PTERO_DIR="/var/www/pterodactyl"
ZIP_URL="https://github.com/maxytmaxyt/setup-util/raw/1e3becd54d5e40d44960546e537cd44590333183/emailutils.zip"

cd $PTERO_DIR

echo "--- Starte Email Utils Installation ---"

# 1. Zip holen und entpacken
echo "Lade Files..."
wget -q $ZIP_URL -O emailutils.zip
unzip -q -o emailutils.zip -d temp_emailutils
# Verschiebe den Inhalt von PanelFiles ins Hauptverzeichnis
cp -r temp_emailutils/PanelFiles/* $PTERO_DIR/
rm -rf temp_emailutils emailutils.zip

# 2. Config Patchen
echo "Patching config/app.php..."
sed -i '/ViewComposerServiceProvider::class,/a \    Pterodactyl\\Providers\\EmailUtilsServiceProvider::class,' config/app.php

# 3. Admin Menu Patchen
echo "Patching admin.blade.php..."
sed -i '/route(.admin.api.)/i \    <li class="{{ ! starts_with(Route::currentRouteName(), .admin.email-utils.) ?: .active. }}">\n        <a href="{{ route(.admin.email-utils.) }}">\n            <i class="fa fa-envelope"></i> <span>Email Utils</span>\n        </a>\n    </li>' resources/views/layouts/admin.blade.php

# 4. Notifications Patchen
patch_notification() {
    FILE=$1
    echo "Patching $FILE"
    sed -i '/Messages\\MailMessage;/a use Pterodactyl\\Services\\EmailUtils\\EmailTemplateManager;' $FILE
    sed -i 's/public function toMail(): MailMessage/public function toMail(mixed $notifiable = null): MailMessage/g' $FILE
    sed -i 's/return (new MailMessage())/$message = (new MailMessage())/g' $FILE
    sed -i '/->action/!b;n;a \        return EmailTemplateManager::applyFromNotification($this, $notifiable, $message);' $FILE
}

for file in app/Notifications/{AccountCreated,SendPasswordReset,AddedToServer,RemovedFromServer,ServerInstalled,MailTested}.php; do
    if [ -f "$file" ]; then
        patch_notification $file
    fi
done

# 5. Abschluss-Tasks
echo "Setze Berechtigungen und lösche Cache..."
chown -R www-data:www-data $PTERO_DIR/*
php artisan view:clear
php artisan config:clear
php artisan route:clear
php artisan migrate --force

echo "--- Fertig! Email Utils sollten jetzt im Admin Panel erscheinen. ---"
