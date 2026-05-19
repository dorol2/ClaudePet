//
//  ClaudePetTests.swift
//  ClaudePetTests
//
//  실제 테스트는 도메인별 파일로 분리:
//  - PetStateEventTests:    이벤트 매핑 / 회귀 방어
//  - PetStatePriorityTests: motion 우선순위
//  - PetStateCancelTests:   cancel 이벤트 + 세션 격리
//  - MotionKeyTests:        MotionKey enum 변환

import Testing
