# New Account Wizard Design

## Goal

Replace only the new-account flow with the two-step macOS-style wizard shown in `docs/design/new_account_modal`, persist every applicable customization, and render the saved virtual card in the existing account history/details side panel. Keep the current edit-account form unchanged.

## Scope

The implementation covers:

- a two-step creation modal based on the two supplied design archives;
- live account/card previews on both steps;
- persisted appearance, card, badge, and tag settings;
- display of the saved virtual card and specifications in the existing account details/history side panel;
- Russian and English localization for all new user-facing copy;
- migration, model, service, state-validation, and affected UI tests;
- macOS build and manual visual verification against both supplied screenshots.

The implementation does not cover:

- redesigning the existing edit-account form;
- a separate balance-reconciliation page;
- new account types for investments or cryptocurrency;
- new currencies beyond USD and KZT;
- a full virtual card on the Dashboard or in account list rows.

Investment, cryptocurrency, and unsupported currency controls may appear as disabled mockup options where they help preserve the supplied visual composition. They must not enter the domain model or be selectable.

## User Flow

### Opening the modal

Creating an account opens the new wizard. Editing an existing account continues to open the current `AccountFormView` behavior and layout. The creation modal uses two steps and retains its draft until the user saves or dismisses it.

### Step 1: Account Details and Initial Balance

The first step follows the first supplied mockup and contains:

- country selector;
- account-type tiles for the four supported types: debit card, bank account, cash, and deposit;
- disabled investment and cryptocurrency tiles;
- institution quick choices plus the complete existing institution picker for non-cash accounts;
- account name;
- initial balance and the supported currency selector;
- a compact optional balance-date control preserving the existing capability.

The right column shows a live card-style preview and a summary of the selected institution, account type, currency, and theme. Every relevant draft change updates the preview immediately.

The Next button validates the current step. The balance must parse and satisfy existing precision and non-negative rules. A non-cash account must have an institution. A custom institution name must be non-empty after trimming. Validation errors remain visible without clearing the draft.

### Step 2: Appearance and Customization

All account types can configure:

- theme preset;
- border/accent tint;
- badge icon;
- account tags.

Debit cards can additionally configure:

- payment network;
- card privilege tier;
- cardholder name;
- whether the cardholder name is displayed;
- four-digit suffix;
- whether the suffix is masked;
- EMV chip style;
- NFC/contactless visibility.

Card-specific controls are hidden for bank accounts, deposits, and cash. Inapplicable card fields are stored as absent rather than as misleading defaults.

The right column renders the finalized virtual card and an account-specification summary. Back returns to Step 1 without losing any values. Add Account validates the appearance draft and atomically saves the account and its appearance. Cancel and the close button discard the unsaved draft.

The four-digit suffix is required to contain exactly four decimal digits for debit cards. Tags are trimmed, have leading `#` characters removed, discard empty values, and are deduplicated case-insensitively while preserving the first spelling and order.

## Persistence Architecture

Add a one-to-one `account_appearances` table. Its `account_id` is both the primary key and a foreign key to `accounts(id)`. The table stores strongly typed raw values for the appearance fields and a JSON array for normalized tags.

The persisted shape includes:

- `account_id`;
- `theme_preset`;
- `accent_tint`;
- `badge_icon`;
- `tags_json`;
- nullable `payment_network`;
- nullable `card_tier`;
- nullable `cardholder_name`;
- nullable `shows_cardholder_name`;
- nullable `card_suffix`;
- nullable `masks_card_suffix`;
- nullable `chip_style`;
- nullable `shows_nfc`.

Use a new schema migration after the current version 5. Existing databases receive the new empty table without rewriting account rows.

Introduce a strongly typed `AccountAppearance` model and enums for each finite option. `Account` carries the loaded appearance used by presentation code. If an existing account has no appearance row, the service supplies a deterministic neutral default in memory. This preserves compatibility for old accounts while avoiding a bulk data migration.

Account creation writes the account, opening-balance transaction when applicable, balance-history entry, and appearance in one database transaction. Any failure rolls the entire creation back.

The current update-account operation neither inserts nor updates appearance data. It must preserve an existing appearance unchanged. A future edit redesign can add a dedicated appearance-update API.

## Presentation Architecture

Keep the existing editing path small and stable. Route new accounts to a dedicated wizard composed of focused SwiftUI units:

- a wizard container responsible for navigation, dismissal, validation messages, and the final save;
- a draft/state model responsible for defaults, normalization, validation, and conversion to service inputs;
- a Step 1 view for financial/account fields;
- a Step 2 view for appearance and conditional card fields;
- a reusable virtual-card preview driven by draft or persisted appearance;
- small selectors for themes, networks, tiers, tints, badges, and tags.

The existing account details/history side panel reuses the virtual-card component with persisted data. It displays the saved visual card and a compact specification block above the existing history content. Accounts without a persisted appearance use the neutral default and remain fully usable.

The Dashboard and account list retain their current layout. They do not render the large virtual card or add new appearance-dependent behavior.

## Defaults

New drafts start with values visually matching the supplied mockups where compatible with current application data:

- country: Kazakhstan;
- account type: debit card;
- currency: KZT;
- theme: Obsidian Matte;
- blue accent tint;
- payment network: Mastercard;
- card tier: Standard;
- cardholder visibility: enabled;
- suffix masking: enabled;
- chip style: Gold Brass;
- NFC visibility: enabled;
- no tags until the user adds them.

Institution and account name defaults must be derived from the live institution catalog rather than hard-coding Kaspi Bank. Existing account-name auto-generation remains available when the user leaves the name blank.

## Localization and Accessibility

All new labels, actions, summaries, validation messages, theme names where appropriate, and accessibility descriptions use the existing RU/EN localization mechanism. Financial values continue to use the app's number-format preferences and monospaced/tabular digits in previews.

Selectors expose selected state, disabled mockup options expose disabled state, icon-only buttons have accessible labels, and color selection is never communicated by color alone.

## Error Handling

Step-level validation errors are shown close to the relevant controls and also prevent forward/final navigation. Persistence failures produce a localized generic save error and keep the entire wizard draft intact for retry. Dismissing the modal remains the only action that discards the draft.

Unknown or invalid appearance raw values read from storage fall back field-by-field to safe neutral defaults rather than causing the account to disappear from lists. Malformed tag JSON is treated as an empty tag list.

## Testing and Verification

Follow test-driven development for production behavior.

Automated coverage must include:

- migration version 6 creates the one-to-one appearance table with the expected columns and constraint;
- an existing version-5 database opens successfully and existing accounts receive in-memory defaults;
- creating an account persists and reloads all common appearance fields;
- creating a debit card persists and reloads every card-specific field;
- non-card accounts store card-specific fields as absent;
- account and appearance creation roll back together on failure;
- the unchanged account-edit operation preserves appearance data;
- tag normalization and deduplication;
- Step 1 validation for balance, institution, and custom institution name;
- Step 2 validation for debit-card suffix;
- conditional visibility/state rules for card-only controls;
- robust fallback for unknown appearance raw values and malformed tag JSON.

Run the complete Swift test suite and the macOS application build. Finally, visually inspect Step 1, Step 2 for both debit-card and non-card drafts, and the persisted account details/history side panel against the supplied screenshots in light mode, while also checking that dark mode remains readable through dynamic system colors.

## Success Criteria

- New-account creation uses the approved two-step design.
- All applicable customization values survive app restart and reload.
- Debit-card-only settings are unavailable and absent for other account types.
- The existing edit-account form behaves as before and preserves saved appearance.
- The account details/history side panel shows the saved virtual card and specifications.
- Existing databases and accounts continue to load safely.
- All automated checks and the macOS build pass.
