# Changelog

## [1.3.6](https://github.com/WolfeLeo2/Zynk/compare/v1.3.5...v1.3.6) (2026-07-01)


### Bug Fixes

* random commit ([5017d05](https://github.com/WolfeLeo2/Zynk/commit/5017d05ebacc88b09e47db6ff93d538c4ed1d530))

## [1.3.5](https://github.com/WolfeLeo2/Zynk/compare/v1.3.4...v1.3.5) (2026-07-01)


### Bug Fixes

* **update bug:** added persistent progress for updates, fix app crash from installing intent ([d8e825b](https://github.com/WolfeLeo2/Zynk/commit/d8e825bdf8cac3552a33c21350d6357dd2e22980))

## [1.3.4](https://github.com/WolfeLeo2/Zynk/compare/v1.3.3...v1.3.4) (2026-07-01)


### Bug Fixes

* **startup:** show a diagnostic error screen instead of a blank screen ([5ed5c2d](https://github.com/WolfeLeo2/Zynk/commit/5ed5c2d551d95810030afca2a3d9e603d84e8c18))

## [1.3.3](https://github.com/WolfeLeo2/Zynk/compare/v1.3.2...v1.3.3) (2026-07-01)


### Bug Fixes

* **release bug:** update github actions to see which env vars fail ([4b90661](https://github.com/WolfeLeo2/Zynk/commit/4b90661213f64484a73a8dd4147a9c2fde368f3b))

## [1.3.2](https://github.com/WolfeLeo2/Zynk/compare/v1.3.1...v1.3.2) (2026-07-01)


### Bug Fixes

* bump desugaring to 2.1.5 ([5ac0fab](https://github.com/WolfeLeo2/Zynk/commit/5ac0fabb81f41b12e522cf89d388a04fc589d489))
* random commit ([48c3b2f](https://github.com/WolfeLeo2/Zynk/commit/48c3b2f25e21a6aa179efd4ac89b072798876db2))
* random commit ([a78d951](https://github.com/WolfeLeo2/Zynk/commit/a78d951e5face63f531171d6f8d39556d58cc66a))
* random commit ([b8f8c87](https://github.com/WolfeLeo2/Zynk/commit/b8f8c87d5a937173cfa8dd2c251778f96ea9a6c8))

## [1.3.1](https://github.com/WolfeLeo2/Zynk/compare/v1.3.0...v1.3.1) (2026-07-01)


### Bug Fixes

* enabled desugaring. ([232bcd1](https://github.com/WolfeLeo2/Zynk/commit/232bcd1fecafd8ffe69235cec7b58e82dab7d4d2))

## [1.3.0](https://github.com/WolfeLeo2/Zynk/compare/v1.2.0...v1.3.0) (2026-07-01)


### Features

* added a self updating check to close sharing gap ([c3a3ca8](https://github.com/WolfeLeo2/Zynk/commit/c3a3ca82edc0d39fb8a0c468122a82e20dd9f67e))
* **auth:** lock on cold start + password-login escape; refresh plan ([dac05be](https://github.com/WolfeLeo2/Zynk/commit/dac05be30e3bf23a37a1290cc331d07a524b548d))
* **auth:** owner self-PIN tile + shared SetPinDialog ([5ac1d77](https://github.com/WolfeLeo2/Zynk/commit/5ac1d7767adeea4827d730723d2532f5f449644d))
* **auth:** PIN-based staff session — Phase 1 foundation ([22107b1](https://github.com/WolfeLeo2/Zynk/commit/22107b154295d61144e0f98ca7af81a5c89bfe93))
* **auth:** PIN-based staff session — Phase 2 (owner set-PIN UI) ([5b7b91c](https://github.com/WolfeLeo2/Zynk/commit/5b7b91c3c804421c0562c00a5a74399d0b9175b7))
* **auth:** PIN-based staff session — Phase 3 (lock screen + auto-lock) ([9aae167](https://github.com/WolfeLeo2/Zynk/commit/9aae1671fae54ac2b4b4d12bddf306331901d1c3))
* **auth:** PIN-based staff session — Phase 5 (login lockout + has-PIN flag) ([5cb1b71](https://github.com/WolfeLeo2/Zynk/commit/5cb1b7197ea236049cc0874c025aca59555e5427))
* **pos:** show salesperson tile on the ticket + add stock_review.md ([847e758](https://github.com/WolfeLeo2/Zynk/commit/847e758cab460fed61cab780addb464b2159f1a0))
* **sales:** salesperson = current logged-in profile (retire staff_members input) ([cbd792e](https://github.com/WolfeLeo2/Zynk/commit/cbd792ee39c0e432952b4438912a239f7d65fb59))
* **update:** in-app auto-update from GitHub Releases (Android) ([37964c0](https://github.com/WolfeLeo2/Zynk/commit/37964c0f4a09cdc7b86d7dbe99b608a6ca4f52ba))


### Bug Fixes

* **errors:** surface user-facing messages, not raw HTTP codes ([6d3fc77](https://github.com/WolfeLeo2/Zynk/commit/6d3fc77930ccc512e03b6745e93ae5bb3343fb9f))
* **expenses:** crash in Log Expense category dropdown (value count != 1) ([4f425f6](https://github.com/WolfeLeo2/Zynk/commit/4f425f69250831fdc26093e904d52d3af95795be))
* new invoice UI and better edit/clone invoice with ability to add products and see stock ([ca80f68](https://github.com/WolfeLeo2/Zynk/commit/ca80f68424851f5f18e4a97ad95a92e0e19a53d1))
* **sync:** add expenses + expense_categories to sync rules ([45292c9](https://github.com/WolfeLeo2/Zynk/commit/45292c9c5cafbe1878f6df0106ae6b9d559868fd))
* **sync:** synthesize id for snapshot tables in sync rules ([74c028c](https://github.com/WolfeLeo2/Zynk/commit/74c028c47be6498b534e9935fc863b4af3f0e108))

## [1.2.0](https://github.com/WolfeLeo2/Zynk/compare/v1.1.5...v1.2.0) (2026-06-24)


### Features

* critical fixes from the review doc (all marked as resolved). Responsive changes (shared util to render either bottomsheet or alert dialogue depending on screen size) ([06bba25](https://github.com/WolfeLeo2/Zynk/commit/06bba25c503fe93c24de8245dd4cade0838fefb7))
* critical fixes from the review doc (all marked as resolved). Responsive changes (shared util to render either bottomsheet or alert dialogue depending on screen size) ([3ede1cd](https://github.com/WolfeLeo2/Zynk/commit/3ede1cda18b7aae89cd4b07ba48318ca8262497d))

## [1.1.5](https://github.com/WolfeLeo2/Zynk/compare/v1.1.4...v1.1.5) (2026-06-15)


### Bug Fixes

* clean fix secrets leak and bump setup-jave to v4 ([01e8009](https://github.com/WolfeLeo2/Zynk/commit/01e80097c3d920e7be7693ebd6e165aa7a896238))

## [1.1.4](https://github.com/WolfeLeo2/Zynk/compare/v1.1.3...v1.1.4) (2026-06-15)


### Bug Fixes

* use getProperty for key.properties and add strict validation ([1185d42](https://github.com/WolfeLeo2/Zynk/commit/1185d42232dcf63b12f497da7e9441e76185bb45))

## [1.1.3](https://github.com/WolfeLeo2/Zynk/compare/v1.1.2...v1.1.3) (2026-06-12)


### Bug Fixes

* sales list branch filter and scroll improvements ([e73c763](https://github.com/WolfeLeo2/Zynk/commit/e73c7638b0b93df5ff76c1378e767cb77cecf558))

## [1.1.2](https://github.com/WolfeLeo2/Zynk/compare/v1.1.1...v1.1.2) (2026-06-12)


### Bug Fixes

* correct key.properties path, heredoc indentation, and add pub get step ([5a1dcfe](https://github.com/WolfeLeo2/Zynk/commit/5a1dcfead7d7da27827b38eea9f84709f8a241dc))

## [1.1.1](https://github.com/WolfeLeo2/Zynk/compare/v1.1.0...v1.1.1) (2026-06-12)


### Bug Fixes

* revert to dart_defines.json for robust env var injection in CI ([736c40e](https://github.com/WolfeLeo2/Zynk/commit/736c40eb63b0d45737e23f4b646bc922e564dbe6))

## [1.1.0](https://github.com/WolfeLeo2/Zynk/compare/v1.0.0...v1.1.0) (2026-06-10)


### Features

* add expense data models ([1f63f5a](https://github.com/WolfeLeo2/Zynk/commit/1f63f5ab3530c1110bd5f95a4b58cc8627fde56c))
* add expenses repository and providers ([e83f45d](https://github.com/WolfeLeo2/Zynk/commit/e83f45deed0d0128f0754f2f61de2c0eb79c14e2))
* add variant UI to product creation and POS selection bottomsheet ([7868ede](https://github.com/WolfeLeo2/Zynk/commit/7868edeaa1c05d93b885ae63618564f68138fcbe))
* added delivery notes, sales filters, and resolved auth sync bugs ([8fff6ed](https://github.com/WolfeLeo2/Zynk/commit/8fff6edb4db4dcba8a036005e1f852fbea93cd73))
* **auth:** add ForgotPasswordScreen (step 1 - email entry) ([aa55203](https://github.com/WolfeLeo2/Zynk/commit/aa55203941b2851b0adb1483aa43b3d6e3800c74))
* **auth:** add ResetPasswordScreen (step 3 - new password) ([a62dc34](https://github.com/WolfeLeo2/Zynk/commit/a62dc340b6ec51a993ecc01cf02195e574fff6d1))
* **auth:** add sendPasswordResetOtp, verifyPasswordResetOtp, updatePassword to AuthService ([229aa3b](https://github.com/WolfeLeo2/Zynk/commit/229aa3bb3caf87155db640b7bae4833427a4ed16))
* **auth:** add VerifyOtpScreen (step 2 - OTP entry) ([fd7d3f7](https://github.com/WolfeLeo2/Zynk/commit/fd7d3f700d1dbf32962b853ff4d0e02f3990df41))
* fix phosphor_flutter package for flutter 3.44 and implement database migrations and product feature updates and stock reports ([095ef7e](https://github.com/WolfeLeo2/Zynk/commit/095ef7e5bead62faa6d6d70b5f4d91221161c69a))
* implement commission management service and dashboard UI updates for expenses and profit tracking ([939f0b2](https://github.com/WolfeLeo2/Zynk/commit/939f0b22f9ee1c59be0eea15c550e80bad6e1d9b))
* implement customer management module with CRUD form and screen support. Branch selection error, ([316f53b](https://github.com/WolfeLeo2/Zynk/commit/316f53b9e86672f0b15308501cdca09a72fb782e))
* implement expenses UI and permissions ([0c046cc](https://github.com/WolfeLeo2/Zynk/commit/0c046cc6e726e9dc969fcff7ed821d1c63920b08))
* Implement sale cloning functionality and enhance approval process ([3e6cf1a](https://github.com/WolfeLeo2/Zynk/commit/3e6cf1aad9d1dc62e1657b39db90467ed6b06d44))
* **routes:** register password reset and change routes ([03e398e](https://github.com/WolfeLeo2/Zynk/commit/03e398ed13487a767f0a826accca73bd6733e41e))
* **settings:** add ChangePasswordScreen ([55625e3](https://github.com/WolfeLeo2/Zynk/commit/55625e321ee148d6be4e4cd22079a6f50747e88a))
* **staff:** add reset password option for owner ([fc87c25](https://github.com/WolfeLeo2/Zynk/commit/fc87c25b6bb01c71f10990343d25742b291f173a))
* **ui:** wire up forgot password and change password entry points ([fffe734](https://github.com/WolfeLeo2/Zynk/commit/fffe73462fb517b22f2b1eb399e7738fc0b20b51))
* variant architecture improvements ([050822b](https://github.com/WolfeLeo2/Zynk/commit/050822bf6abcf446f3d832ef8c662fdd3e24c827))


### Bug Fixes

* split vercel.json buildCommand under 256 char limit ([59c10f7](https://github.com/WolfeLeo2/Zynk/commit/59c10f75c9fcf23294ef30fff85a2d22f9369264))

## 1.0.0 (2026-06-10)


### Features

* add expense data models ([1f63f5a](https://github.com/WolfeLeo2/Zynk/commit/1f63f5ab3530c1110bd5f95a4b58cc8627fde56c))
* add expenses repository and providers ([e83f45d](https://github.com/WolfeLeo2/Zynk/commit/e83f45deed0d0128f0754f2f61de2c0eb79c14e2))
* add variant UI to product creation and POS selection bottomsheet ([7868ede](https://github.com/WolfeLeo2/Zynk/commit/7868edeaa1c05d93b885ae63618564f68138fcbe))
* **auth:** add ForgotPasswordScreen (step 1 - email entry) ([aa55203](https://github.com/WolfeLeo2/Zynk/commit/aa55203941b2851b0adb1483aa43b3d6e3800c74))
* **auth:** add ResetPasswordScreen (step 3 - new password) ([a62dc34](https://github.com/WolfeLeo2/Zynk/commit/a62dc340b6ec51a993ecc01cf02195e574fff6d1))
* **auth:** add sendPasswordResetOtp, verifyPasswordResetOtp, updatePassword to AuthService ([229aa3b](https://github.com/WolfeLeo2/Zynk/commit/229aa3bb3caf87155db640b7bae4833427a4ed16))
* **auth:** add VerifyOtpScreen (step 2 - OTP entry) ([fd7d3f7](https://github.com/WolfeLeo2/Zynk/commit/fd7d3f700d1dbf32962b853ff4d0e02f3990df41))
* fix phosphor_flutter package for flutter 3.44 and implement database migrations and product feature updates and stock reports ([095ef7e](https://github.com/WolfeLeo2/Zynk/commit/095ef7e5bead62faa6d6d70b5f4d91221161c69a))
* implement commission management service and dashboard UI updates for expenses and profit tracking ([939f0b2](https://github.com/WolfeLeo2/Zynk/commit/939f0b22f9ee1c59be0eea15c550e80bad6e1d9b))
* implement customer management module with CRUD form and screen support. Branch selection error, ([316f53b](https://github.com/WolfeLeo2/Zynk/commit/316f53b9e86672f0b15308501cdca09a72fb782e))
* implement expenses UI and permissions ([0c046cc](https://github.com/WolfeLeo2/Zynk/commit/0c046cc6e726e9dc969fcff7ed821d1c63920b08))
* Implement sale cloning functionality and enhance approval process ([3e6cf1a](https://github.com/WolfeLeo2/Zynk/commit/3e6cf1aad9d1dc62e1657b39db90467ed6b06d44))
* **routes:** register password reset and change routes ([03e398e](https://github.com/WolfeLeo2/Zynk/commit/03e398ed13487a767f0a826accca73bd6733e41e))
* **settings:** add ChangePasswordScreen ([55625e3](https://github.com/WolfeLeo2/Zynk/commit/55625e321ee148d6be4e4cd22079a6f50747e88a))
* **staff:** add reset password option for owner ([fc87c25](https://github.com/WolfeLeo2/Zynk/commit/fc87c25b6bb01c71f10990343d25742b291f173a))
* **ui:** wire up forgot password and change password entry points ([fffe734](https://github.com/WolfeLeo2/Zynk/commit/fffe73462fb517b22f2b1eb399e7738fc0b20b51))
* variant architecture improvements ([050822b](https://github.com/WolfeLeo2/Zynk/commit/050822bf6abcf446f3d832ef8c662fdd3e24c827))


### Bug Fixes

* split vercel.json buildCommand under 256 char limit ([59c10f7](https://github.com/WolfeLeo2/Zynk/commit/59c10f75c9fcf23294ef30fff85a2d22f9369264))
