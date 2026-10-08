#!/usr/bin/env python3
"""Merge translations into assets/translations/*.dart and apply scoped .tr() replacements."""

from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TRANS_DIR = ROOT / "assets" / "translations"
LIB = ROOT / "lib"

T_ROWS = r"""
common.cancel|Cancel|Annuler|إلغاء
common.save|Save|Enregistrer|حفظ
common.delete|Delete|Supprimer|حذف
common.close|Close|Fermer|إغلاق
common.ok|OK|OK|حسنًا
common.retry|Retry|Réessayer|إعادة المحاولة
common.apply|Apply|Appliquer|تطبيق
common.reset|Reset|Réinitialiser|إعادة ضبط
common.add|Add|Ajouter|إضافة
common.edit|Edit|Modifier|تعديل
common.search|Search|Rechercher|بحث
common.loading|Loading...|Chargement...|جاري التحميل...
common.error|Error|Erreur|خطأ
common.yes|Yes|Oui|نعم
common.no|No|Non|لا
common.print|Print|Imprimer|طباعة
common.back|Back|Retour|رجوع
common.remove|Remove|Retirer|إزالة
common.resume|Resume|Reprendre|استئناف
common.version|Version {v}|Version {v}|الإصدار {v}
splash.title|Offline POS|PDV hors ligne|نقطة بيع دون اتصال
splash.subtitle|Point of Sale System|Système de point de vente|نظام نقطة البيع
splash.initializing|Initializing System...|Initialisation du système...|جاري تهيئة النظام...
splash.please_wait|Please wait while we set up your POS|Veuillez patienter pendant la configuration|يرجى الانتظار أثناء الإعداد
forgot.title|Password Recovery|Récupération du mot de passe|استعادة كلمة المرور
forgot.headline|Recover Admin Password|Récupérer le mot de passe admin|استعادة كلمة مرور المسؤول
forgot.intro|Answer the security question you configured during business setup to reset the admin password. This process works entirely offline.|Répondez à la question de sécurité configurée lors de l'installation pour réinitialiser le mot de passe administrateur. Tout fonctionne hors ligne.|أجب عن سؤال الأمان الذي ضبطته أثناء إعداد النشاط لإعادة تعيين كلمة مرور المسؤول. يعمل ذلك بالكامل دون اتصال.
forgot.security_question|Security Question|Question de sécurité|سؤال الأمان
forgot.book_question|What is your favourite book?|Quel est votre livre préféré ?|ما كتابك المفضل؟
forgot.answer_hint|Enter the answer you provided during business setup|Saisissez la réponse donnée lors de l'installation|أدخل الإجابة التي قدمتها أثناء الإعداد
forgot.verify|Verify Answer|Vérifier la réponse|تحقق من الإجابة
forgot.verified|Answer Verified|Réponse vérifiée|تم التحقق من الإجابة
dashboard.title|Dashboard|Tableau de bord|لوحة التحكم
dashboard.overview|Business overview|Aperçu de l'activité|نظرة عامة على النشاط
dashboard.welcome|Welcome back! Here's your business overview|Bon retour ! Voici l'aperçu de votre activité|مرحبًا بعودتك! إليك نظرة عامة على نشاطك
dashboard.error_loading|Error loading data|Erreur de chargement des données|خطأ في تحميل البيانات
dashboard.retry|Retry|Réessayer|إعادة المحاولة
dashboard.no_customers|No customers yet|Pas encore de clients|لا يوجد عملاء بعد
dashboard.active_week|Active this week: {n}|Actifs cette semaine : {n}|نشط هذا الأسبوع: {n}
dashboard.todays_sales|Today's Sales|Ventes du jour|مبيعات اليوم
dashboard.total_orders|Total Orders|Total des commandes|إجمالي الطلبات
dashboard.customers|Customers|Clients|العملاء
dashboard.products|Products|Produits|المنتجات
dashboard.no_sales_yet|No sales yet|Pas encore de ventes|لا مبيعات بعد
dashboard.no_orders_yet|No orders yet|Pas encore de commandes|لا طلبات بعد
dashboard.no_products_yet|No products yet|Pas encore de produits|لا منتجات بعد
dashboard.sales_analytics|Sales Analytics|Analyses des ventes|تحليلات المبيعات
dashboard.last_7_days|Last 7 Days|7 derniers jours|آخر 7 أيام
dashboard.top_products|Top Products|Meilleurs produits|أفضل المنتجات
dashboard.no_products_data|No products data|Aucune donnée produit|لا بيانات للمنتجات
dashboard.customer_insights|Customer Insights|Aperçu clients|رؤى العملاء
dashboard.new_customers|New Customers|Nouveaux clients|عملاء جدد
dashboard.returning_customers|Returning Customers|Clients récurrents|عملاء عائدون
dashboard.avg_order_value|Avg Order Value|Panier moyen|متوسط قيمة الطلب
dashboard.inventory_alerts|Inventory Alerts|Alertes de stock|تنبيهات المخزون
dashboard.no_alerts|No alerts|Aucune alerte|لا تنبيهات
dashboard.performance|Performance|Performance|الأداء
dashboard.conversion_rate|Conversion Rate|Taux de conversion|معدل التحويل
dashboard.profit_margin|Profit Margin|Marge bénéficiaire|هامش الربح
dashboard.growth_rate|Growth Rate|Taux de croissance|معدل النمو
dashboard.quick_purchase_invoice|Purchase Invoice|Facture d'achat|فاتورة شراء
dashboard.quick_stock_movement|Stock Movement|Mouvement de stock|حركة المخزون
dashboard.quick_purchase_order|Purchase Order|Bon de commande|أمر شراء
dashboard.quick_employee|Employee|Employé|موظف
dashboard.quick_category|Category|Catégorie|فئة
dashboard.quick_inventory|Inventory|Inventaire|المخزون
dashboard.quick_return|Return|Retour|إرجاع
products.title|Products|Produits|المنتجات
pos.cart_empty_print|Cart is empty. Nothing to print.|Le panier est vide. Rien à imprimer.|السلة فارغة. لا شيء للطباعة.
pos.cart_empty_add|Cart is empty. Add items to cart first.|Le panier est vide. Ajoutez des articles d'abord.|السلة فارغة. أضف أصنافًا أولاً.
pos.cart_empty_amount|No items with amount field in cart.|Aucun article avec montant dans le panier.|لا توجد أصناف بمبلغ في السلة.
pos.cart_empty_hold|Cart is empty. Nothing to hold.|Le panier est vide. Rien à mettre en attente.|السلة فارغة. لا شيء للتعليق.
pos.keyboard_shortcuts|Keyboard Shortcuts (Desktop)|Raccourcis clavier (bureau)|اختصارات لوحة المفاتيح (سطح المكتب)
pos.no_held|No held orders available.|Aucune commande en attente.|لا توجد طلبات معلقة.
pos.held_orders|Held Orders|Commandes en attente|طلبات معلقة
pos.delete_held_title|Delete Held Order?|Supprimer la commande en attente ?|حذف الطلب المعلق؟
pos.delete_held_body|This action cannot be undone. Are you sure you want to delete this held order?|Action irréversible. Supprimer cette commande en attente ?|لا يمكن التراجع. هل تريد حذف هذا الطلب المعلق؟
pos.delete_held_appbar|Delete Held Order|Supprimer commande en attente|حذف طلب معلق
pos.order_resumed|Order resumed successfully!|Commande reprise avec succès !|تم استئناف الطلب بنجاح!
pos.held_deleted|Held order deleted successfully!|Commande en attente supprimée !|تم حذف الطلب المعلق بنجاح!
pos.enter_valid_price|Please enter a valid price greater than zero.|Saisissez un prix valide supérieur à zéro.|أدخل سعرًا صالحًا أكبر من الصفر.
pos.edit_price|Edit Price|Modifier le prix|تعديل السعر
pos.apply_discount|Apply Discount|Appliquer une remise|تطبيق خصم
pos.discount_removed|Item discount removed|Remise article supprimée|تمت إزالة خصم الصنف
pos.remove_discount|Remove Discount|Supprimer la remise|إزالة الخصم
pos.hold_order|Hold Order|Mettre en attente|تعليق الطلب
pos.resume_order|Resume Order|Reprendre la commande|استئناف الطلب
pos.clear_cart|Clear Cart|Vider le panier|إفراغ السلة
pos.sales|Sales|Ventes|المبيعات
pos.reports_nav|Reports|Rapports|التقارير
pos.split_customer|Select a customer to use split payments|Sélectionnez un client pour le paiement fractionné|اختر عميلاً لاستخدام الدفع المجزأ
pos.error_categories|Error loading categories|Erreur chargement catégories|خطأ في تحميل الفئات
pos.clear_filters|Clear filters & show all|Effacer filtres et tout afficher|مسح المرشحات وعرض الكل
pos.add_to_cart|Add to Cart|Ajouter au panier|إضافة للسلة
pos.view_details|View Details|Voir les détails|عرض التفاصيل
pos.edit_product|Edit Product|Modifier le produit|تعديل المنتج
pos.walk_in|Walk-in Customer|Client sans compte|عميل مباشر
pos.walk_in_short|Walk-in|Sans compte|مباشر
pos.split_bill|Split Bill|Fractionner la note|تقسيم الفاتورة
pos.payment|Payment|Paiement|الدفع
pos.subtotal|Subtotal|Sous-total|المجموع الفرعي
pos.discounts|Discounts|Remises|الخصومات
pos.total|Total|Total|الإجمالي
pos.percent_symbol|%|%|٪
pos.subtotal_colon|Subtotal:|Sous-total :|المجموع الفرعي:
pos.assign_imei|Assign IMEI|Attribuer IMEI|تعيين IMEI
pos.enter_barcode|Enter Barcode|Saisir le code-barres|إدخال الباركود
pos.add_product|Add Product|Ajouter le produit|إضافة المنتج
pos.in_cart|In Cart|Dans le panier|في السلة
pos.trade_in_title|Trade-in Intake|Reprise d'appareil|استلام استبدال
pos.save_trade_in|Save Trade-in|Enregistrer la reprise|حفظ الاستبدال
pos.print_receipt_q|Print Receipt?|Imprimer le ticket ?|طباعة الإيصال؟
pos.split_need_two|Need at least 2 items to split bill|Au moins 2 articles pour fractionner|يلزم صنفان على الأقل لتقسيم الفاتورة
pos.split_bill_title|Split Bill|Fractionner la note|تقسيم الفاتورة
pos.bill1_total|Bill 1 Total:|Total facture 1 :|إجمالي الفاتورة 1:
pos.bill2_total|Bill 2 Total:|Total facture 2 :|إجمالي الفاتورة 2:
pos.split_process|Split & Process|Fractionner et traiter|تقسيم ومعالجة
pos.print_failed|Print Failed|Échec de l'impression|فشل الطباعة
pos.retry_print|Retry Print|Réessayer l'impression|إعادة محاولة الطباعة
pos.finding_printers|Finding Printers|Recherche d'imprimantes|البحث عن الطابعات
pos.select_thermal|Select Thermal Printer|Sélection imprimante thermique|اختر طابعة حرارية
pos.available_printers|Available printers:|Imprimantes disponibles :|الطابعات المتاحة:
pos.enter_ip|Enter IP manually|Saisir l'IP manuellement|إدخال IP يدويًا
pos.enter_printer_ip|Enter Printer IP Address|Adresse IP de l'imprimante|عنوان IP للطابعة
pos.printing_receipt|Printing receipt...|Impression du ticket...|جاري طباعة الإيصال...
pos.receipt_printed_excl|Receipt printed successfully!|Ticket imprimé !|تمت طباعة الإيصال!
pos.reprint|Reprint|Réimprimer|إعادة طباعة
pos.reorder|Reorder|Recommander|إعادة الطلب
pos.add_item|Add Item|Ajouter un article|إضافة صنف
pos.delete_sale|Delete Sale|Supprimer la vente|حذف البيع
pos.save_changes|Save Changes|Enregistrer les modifications|حفظ التغييرات
pos.no_products_found|No products found|Aucun produit trouvé|لم يُعثر على منتجات
pos.delete_sale_q|Delete Sale?|Supprimer la vente ?|حذف البيع؟
pos.customers_loading|Loading...|Chargement...|جاري التحميل...
pos.customers_error|Error loading customers|Erreur chargement clients|خطأ في تحميل العملاء
pos.no_customers_found|No customers found|Aucun client trouvé|لم يُعثر على عملاء
""".strip()


def parse_rows():
    rows = []
    for line in T_ROWS.splitlines():
        line = line.strip()
        if not line:
            continue
        p = line.split("|")
        if len(p) == 4:
            rows.append(tuple(x.strip() for x in p))
    return rows


def rows_to_nested(flat_rows):
    en, fr, ar = {}, {}, {}

    def set_deep(d, parts, value):
        cur = d
        for x in parts[:-1]:
            cur = cur.setdefault(x, {})
        cur[parts[-1]] = value

    for key_path, te, tf, ta in flat_rows:
        parts = key_path.split(".")
        set_deep(en, parts, te)
        set_deep(fr, parts, tf)
        set_deep(ar, parts, ta)
    return en, fr, ar


def deep_merge(base, extra):
    out = json.loads(json.dumps(base))
    for k, v in extra.items():
        if k in out and isinstance(out[k], dict) and isinstance(v, dict):
            out[k] = deep_merge(out[k], v)
        else:
            out[k] = v
    return out


def ensure_import(content: str) -> str:
    if "easy_localization" in content:
        return content
    return content.replace(
        "import 'package:flutter/material.dart';",
        "import 'package:easy_localization/easy_localization.dart';\nimport 'package:flutter/material.dart';",
        1,
    )


def apply_replacements(path: Path, pairs: list[tuple[str, str]]) -> bool:
    s = path.read_text(encoding="utf-8")
    orig = s
    pairs = sorted(pairs, key=lambda x: len(x[0]), reverse=True)
    for old, new in pairs:
        s = s.replace(old, new)
    if s == orig:
        return False
    s = ensure_import(s)
    path.write_text(s, encoding="utf-8")
    return True


def main():
    flat = parse_rows()
    en_new, fr_new, ar_new = rows_to_nested(flat)
    for lang, extra in ("en", en_new), ("fr", fr_new), ("ar", ar_new):
        p = TRANS_DIR / f"{lang}.json"
        merged = deep_merge(json.loads(p.read_text(encoding="utf-8")), extra)
        p.write_text(json.dumps(merged, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    global_pairs = [
        ("const Text('Cancel')", "Text('common.cancel'.tr())"),
        ("const Text('Delete')", "Text('common.delete'.tr())"),
        ("const Text('Save')", "Text('common.save'.tr())"),
        ("const Text('Close')", "Text('common.close'.tr())"),
        ("const Text('OK')", "Text('common.ok'.tr())"),
        ("const Text('Yes')", "Text('common.yes'.tr())"),
        ("const Text('No')", "Text('common.no'.tr())"),
        ("const Text('Reset')", "Text('common.reset'.tr())"),
        ("const Text('Apply')", "Text('common.apply'.tr())"),
        ("const Text('Print')", "Text('common.print'.tr())"),
        ("const Text('Edit')", "Text('common.edit'.tr())"),
        ("child: const Text('Close')", "child: Text('common.close'.tr())"),
        ("child: const Text('Cancel')", "child: Text('common.cancel'.tr())"),
    ]

    pos = LIB / "screens" / "pos_screen.dart"
    pos_pairs = [
        ("Text('Cart is empty. Nothing to print.')", "Text('pos.cart_empty_print'.tr())"),
        ("Text('Cart is empty. Add items to cart first.')", "Text('pos.cart_empty_add'.tr())"),
        ("Text('No items with amount field in cart.')", "Text('pos.cart_empty_amount'.tr())"),
        ("Text('Cart is empty. Nothing to hold.')", "Text('pos.cart_empty_hold'.tr())"),
        ("const Text('Keyboard Shortcuts (Desktop)')", "Text('pos.keyboard_shortcuts'.tr())"),
        ("Text('No held orders available.')", "Text('pos.no_held'.tr())"),
        ("const Text('Held Orders')", "Text('pos.held_orders'.tr())"),
        ("Text('Delete Held Order?')", "Text('pos.delete_held_title'.tr())"),
        ("content: const Text('This action cannot be undone. Are you sure you want to delete this held order?')", "content: Text('pos.delete_held_body'.tr())"),
        ("title: const Text('Delete Held Order')", "title: Text('pos.delete_held_appbar'.tr())"),
        ("Text('Order resumed successfully!')", "Text('pos.order_resumed'.tr())"),
        ("Text('Held order deleted successfully!')", "Text('pos.held_deleted'.tr())"),
        ("const Text('Resume')", "Text('common.resume'.tr())"),
        ("Text('Please enter a valid price greater than zero.')", "Text('pos.enter_valid_price'.tr())"),
        ("title: const Text('Edit Price')", "title: Text('pos.edit_price'.tr())"),
        ("title: const Text('Apply Discount')", "title: Text('pos.apply_discount'.tr())"),
        ("Text('Item discount removed')", "Text('pos.discount_removed'.tr())"),
        ("const Text('Remove Discount')", "Text('pos.remove_discount'.tr())"),
        ("Text('Hold Order')", "Text('pos.hold_order'.tr())"),
        ("const Text('Resume Order')", "Text('pos.resume_order'.tr())"),
        ("Text('Clear Cart')", "Text('pos.clear_cart'.tr())"),
        ("Text('Select a customer to use split payments')", "Text('pos.split_customer'.tr())"),
        ("child: Center(child: Text('Error loading categories'))", "child: Center(child: Text('pos.error_categories'.tr()))"),
        ("const Text('Clear filters & show all')", "Text('pos.clear_filters'.tr())"),
        ("const Text('Add to Cart')", "Text('pos.add_to_cart'.tr())"),
        ("const Text('View Details')", "Text('pos.view_details'.tr())"),
        ("const Text('Edit Product')", "Text('pos.edit_product'.tr())"),
        ("const Text('Walk-in Customer')", "Text('pos.walk_in'.tr())"),
        ("const Text('Walk-in',", "Text('pos.walk_in_short'.tr(),"),
        ("const Text('Walk-in Customer',", "Text('pos.walk_in'.tr(),"),
        ("const Text('Split Bill')", "Text('pos.split_bill'.tr())"),
        (
            """                  const Text('Payment',
                      style:
                          TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),""",
            """                  Text('pos.payment'.tr(),
                      style:
                          const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),""",
        ),
        (
            """                            const Text('Bill 1 Total:',
                                style: TextStyle(fontWeight: FontWeight.w600)),""",
            """                            Text('pos.bill1_total'.tr(),
                                style: const TextStyle(fontWeight: FontWeight.w600)),""",
        ),
        (
            """                            const Text('Bill 2 Total:',
                                style: TextStyle(fontWeight: FontWeight.w600)),""",
            """                            Text('pos.bill2_total'.tr(),
                                style: const TextStyle(fontWeight: FontWeight.w600)),""",
        ),
        ("const Text('Split & Process')", "Text('pos.split_process'.tr())"),
        ("const Text('Assign IMEI')", "Text('pos.assign_imei'.tr())"),
        ("label: Text('In Cart')", "label: Text('pos.in_cart'.tr())"),
        ("const Text('Save Trade-in')", "Text('pos.save_trade_in'.tr())"),
        ("Text('Trade-in Intake')", "Text('pos.trade_in_title'.tr())"),
        ("const Text('Enter Barcode')", "Text('pos.enter_barcode'.tr())"),
        ("const Text('Add Product')", "Text('pos.add_product'.tr())"),
        ("Text('Print Receipt?')", "Text('pos.print_receipt_q'.tr())"),
        ("Text('Need at least 2 items to split bill')", "Text('pos.split_need_two'.tr())"),
        ("Text('Split Bill')", "Text('pos.split_bill_title'.tr())"),
        ("Text('Print Failed')", "Text('pos.print_failed'.tr())"),
        ("label: Text('Retry Print')", "label: Text('pos.retry_print'.tr())"),
        ("Text('Finding Printers')", "Text('pos.finding_printers'.tr())"),
        ("const Text('Select Thermal Printer')", "Text('pos.select_thermal'.tr())"),
        ("const Text('Available printers:')", "Text('pos.available_printers'.tr())"),
        ("const Text('Enter IP manually')", "Text('pos.enter_ip'.tr())"),
        ("const Text('Enter Printer IP Address')", "Text('pos.enter_printer_ip'.tr())"),
        ("Text('Printing receipt...')", "Text('pos.printing_receipt'.tr())"),
        ("Text('Receipt printed successfully!')", "Text('pos.receipt_printed_excl'.tr())"),
        ("const Text('Reprint')", "Text('pos.reprint'.tr())"),
        ("const Text('Reorder')", "Text('pos.reorder'.tr())"),
        ("const Text('Add Item')", "Text('pos.add_item'.tr())"),
        ("const Text('Delete Sale')", "Text('pos.delete_sale'.tr())"),
        ("const Text('Save Changes')", "Text('pos.save_changes'.tr())"),
        ("Text('Delete Sale?')", "Text('pos.delete_sale_q'.tr())"),
        ("Text('No products found')", "Text('pos.no_products_found'.tr())"),
        ("Text('Loading...', style: TextStyle(fontSize: 12))", "Text('pos.customers_loading'.tr(), style: const TextStyle(fontSize: 12))"),
        ("Text('Error loading customers',", "Text('pos.customers_error'.tr(),"),
        ("Text('No customers found')", "Text('pos.no_customers_found'.tr())"),
        ("value: 'percentage', child: Text('%')", "value: 'percentage', child: Text('pos.percent_symbol'.tr())"),
    ]
    # Dangerous global: Text('Sales') replaced in pos - might break other contexts in same file
    apply_replacements(pos, pos_pairs)

    splash = LIB / "screens" / "splash_screen.dart"
    apply_replacements(
        splash,
        [
            ("Text(\n                              'Offline POS',", "Text(\n                              'splash.title'.tr(),"),
            ("Text(\n                              'Point of Sale System',", "Text(\n                              'splash.subtitle'.tr(),"),
            ("Text(\n                              'Initializing System...',", "Text(\n                              'splash.initializing'.tr(),"),
            ("Text(\n                              'Please wait while we set up your POS',", "Text(\n                              'splash.please_wait'.tr(),"),
            ("'Version 1.0.0',", "'common.version'.tr(namedArgs: {'v': '1.0.0'}),"),
        ],
    )

    forgot = LIB / "screens" / "forgot_password_screen.dart"
    apply_replacements(
        forgot,
        [
            ("title: const Text('Password Recovery')", "title: Text('forgot.title'.tr())"),
            ("'Recover Admin Password',", "'forgot.headline'.tr(),"),
            (
                "'Answer the security question you configured during business setup to reset the admin password. This process works entirely offline.',",
                "'forgot.intro'.tr(),",
            ),
            ("const Text(\n                  'Security Question',", "Text(\n                  'forgot.security_question'.tr(),"),
            ("'What is your favourite book?',", "'forgot.book_question'.tr(),"),
            ("hintText: 'Enter the answer you provided during business setup',", "hintText: 'forgot.answer_hint'.tr(),"),
            ("Text(_answerVerified ? 'Answer Verified' : 'Verify Answer')", "Text(_answerVerified ? 'forgot.verified'.tr() : 'forgot.verify'.tr())"),
        ],
    )

    dash = LIB / "screens" / "dashboard_screen.dart"
    apply_replacements(
        dash,
        [
            ("'Dashboard',", "'dashboard.title'.tr(),"),
            ("? 'Business overview'", "? 'dashboard.overview'.tr()"),
            (": 'Welcome back! Here\\'s your business overview'", ": 'dashboard.welcome'.tr()"),
            ("'Error loading data',", "'dashboard.error_loading'.tr(),"),
            ("child: const Text('Retry')", "child: Text('dashboard.retry'.tr())"),
            ("? 'No customers yet'", "? 'dashboard.no_customers'.tr()"),
            ("title: 'Today\\'s Sales',", "title: 'dashboard.todays_sales'.tr(),"),
            ("title: 'Total Orders',", "title: 'dashboard.total_orders'.tr(),"),
            ("title: 'Customers',", "title: 'dashboard.customers'.tr(),"),
            ("title: 'Products',", "title: 'dashboard.products'.tr(),"),
            ("change: totalSales > 0 ? '+12.5%' : 'No sales yet',", "change: totalSales > 0 ? '+12.5%' : 'dashboard.no_sales_yet'.tr(),"),
            ("change: totalOrders > 0 ? '+8.2%' : 'No orders yet',", "change: totalOrders > 0 ? '+8.2%' : 'dashboard.no_orders_yet'.tr(),"),
            ("change: products.length > 0 ? '+5.7%' : 'No products yet',", "change: products.length > 0 ? '+5.7%' : 'dashboard.no_products_yet'.tr(),"),
            ("'Sales Analytics',", "'dashboard.sales_analytics'.tr(),"),
            ("'Last 7 Days',", "'dashboard.last_7_days'.tr(),"),
            ("'Top Products',", "'dashboard.top_products'.tr(),"),
            ("'No products data',", "'dashboard.no_products_data'.tr(),"),
            ("'Customer Insights',", "'dashboard.customer_insights'.tr(),"),
            ("'New Customers',", "'dashboard.new_customers'.tr(),"),
            ("'Returning Customers',", "'dashboard.returning_customers'.tr(),"),
            ("'Avg Order Value',", "'dashboard.avg_order_value'.tr(),"),
            ("'Inventory Alerts',", "'dashboard.inventory_alerts'.tr(),"),
            ("'No alerts',", "'dashboard.no_alerts'.tr(),"),
            ("'Performance',", "'dashboard.performance'.tr(),"),
            ("'Conversion Rate',", "'dashboard.conversion_rate'.tr(),"),
            ("'Profit Margin',", "'dashboard.profit_margin'.tr(),"),
            ("'Growth Rate',", "'dashboard.growth_rate'.tr(),"),
            ("label: 'Purchase Invoice',", "label: 'dashboard.quick_purchase_invoice'.tr(),"),
            ("label: 'Stock Movement',", "label: 'dashboard.quick_stock_movement'.tr(),"),
            ("label: 'Purchase Order',", "label: 'dashboard.quick_purchase_order'.tr(),"),
            ("label: 'Employee',", "label: 'dashboard.quick_employee'.tr(),"),
            ("label: 'Category',", "label: 'dashboard.quick_category'.tr(),"),
            ("label: 'Inventory',", "label: 'dashboard.quick_inventory'.tr(),"),
            ("label: 'Return',", "label: 'dashboard.quick_return'.tr(),"),
        ],
    )

    products = LIB / "screens" / "products_screen.dart"
    apply_replacements(
        products,
        [
            ("? const Text('Products')", "? Text('products.title'.tr())"),
        ],
    )

    global_pairs.append(("const Text('Retry')", "Text('common.retry'.tr())"))
    skip = {"database.g.dart"}
    for path in LIB.rglob("*.dart"):
        if any(x in str(path) for x in skip):
            continue
        apply_replacements(path, global_pairs)

    print("Done: merged JSON + global + scoped replacements.")


if __name__ == "__main__":
    main()
