# Changelog

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
