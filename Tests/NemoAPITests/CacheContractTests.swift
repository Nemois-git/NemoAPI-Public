//
//  CacheContractTests.swift
//  NemoAPI
//
//  Created by Jeongcheol Kim on 10/20/26.
//  Copyright (c) 2026 Jeongcheol Kim (nemois). All rights reserved.
//
//  Licensed under the MIT License.
//  See the LICENSE file in the project root for license information.
//

import Foundation
import NemoAPI
import Testing

@Suite("Cache contract")
struct CacheContractTests {
    @Test func endpointsAreUncachedByDefault() {
        #expect(DefaultUncached.cacheable == false)
        #expect(DefaultUncached.ttl == .zero)
        #expect(DefaultUncached.isCacheContractValid)
    }

    @Test func consistentDeclarationsAreValid() {
        #expect(PublicCached.isCacheContractValid)
        #expect(StrictCached.isCacheContractValid)
        #expect(OptionalCached.isCacheContractValid)
        #expect(SubSecondCached.isCacheContractValid)
    }

    @Test func inconsistentDeclarationsAreInvalid() {
        #expect(PostCached.isCacheContractValid == false)
        #expect(ZeroTTLCached.isCacheContractValid == false)
        #expect(UncachedWithTTL.isCacheContractValid == false)
    }

    @Test func maxAgeFollowsTtlInWholeSeconds() {
        #expect(PublicCached.maxAgeSeconds == 300)
        #expect(StrictCached.maxAgeSeconds == 3600)
        #expect(DefaultUncached.maxAgeSeconds == 0)
        #expect(UncachedWithTTL.maxAgeSeconds == 0)
    }

    @Test func negativeTtlIsInvalidAndNeverStored() {
        #expect(NegativeTTLCached.isCacheContractValid == false)
        #expect(NegativeTTLCached.maxAgeSeconds == 0)
        #expect(NegativeTTLCached.cacheControlValue == "no-store")
    }

    @Test func subSecondTtlRoundsUpSoItNeverCollapsesToZero() {
        #expect(SubSecondCached.maxAgeSeconds == 1)
    }

    @Test func cacheControlIsPublicOnlyWithoutAuth() {
        #expect(PublicCached.cacheControlValue == "public, max-age=300")
        #expect(SubSecondCached.cacheControlValue == "public, max-age=1")
    }

    @Test func anyAuthRequirementMakesTheCachePrivate() {
        #expect(StrictCached.cacheControlValue == "private, max-age=3600")
        #expect(OptionalCached.cacheControlValue == "private, max-age=30")
    }

    @Test func uncachedOrInconsistentEndpointsAreNeverStored() {
        #expect(DefaultUncached.cacheControlValue == "no-store")
        #expect(PostCached.cacheControlValue == "no-store")
        #expect(ZeroTTLCached.cacheControlValue == "no-store")
    }

    @Test func durationHelpersReadAsIntent() {
        #expect(Duration.minutes(5) == .seconds(300))
        #expect(Duration.hours(2) == .seconds(7200))
        #expect(Duration.days(1) == .seconds(86400))
    }
}
