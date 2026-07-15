import 'package:household_ledger/model/metadata_tag.dart';
import 'package:test/test.dart';

void main() {
  group('MetadataTagCodeGenerator', () {
    test('새 사용자 카테고리에 첫 2문자 코드를 할당한다', () {
      final code = MetadataTagCodeGenerator.nextUserCode(
        type: MetadataTagType.category,
        tags: const <MetadataTag>[
          MetadataTag(type: MetadataTagType.category, code: 'F', label: '외식비'),
        ],
      );

      expect(code, '00');
      expect(code, hasLength(2));
    });

    test('이미 사용 중인 사용자 카테고리 코드를 건너뛴다', () {
      final code = MetadataTagCodeGenerator.nextUserCode(
        type: MetadataTagType.category,
        tags: const <MetadataTag>[
          MetadataTag(
            type: MetadataTagType.category,
            code: '00',
            label: '사용자 카테고리 1',
          ),
          MetadataTag(
            type: MetadataTagType.category,
            code: '01',
            label: '사용자 카테고리 2',
          ),
        ],
      );

      expect(code, '02');
    });

    test('다른 태그 종류에서 같은 코드를 사용해도 충돌하지 않는다', () {
      final code = MetadataTagCodeGenerator.nextUserCode(
        type: MetadataTagType.category,
        tags: const <MetadataTag>[
          MetadataTag(
            type: MetadataTagType.paymentMethod,
            code: '00',
            label: '사용자 결제수단',
          ),
        ],
      );

      expect(code, '00');
    });

    test('가능한 모든 2문자 코드가 사용 중이면 null을 반환한다', () {
      const characters = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';
      final tags = <MetadataTag>[
        for (var first = 0; first < characters.length; first++)
          for (var second = 0; second < characters.length; second++)
            MetadataTag(
              type: MetadataTagType.category,
              code: '${characters[first]}${characters[second]}',
              label: '사용자 카테고리',
            ),
      ];

      expect(
        MetadataTagCodeGenerator.nextUserCode(
          type: MetadataTagType.category,
          tags: tags,
        ),
        isNull,
      );
    });
  });

  group('시스템 기본 카테고리', () {
    test('모든 코드가 1문자이며 스포츠 카테고리도 시스템 기본이다', () {
      final categoryCodes =
          systemMetadataTagLocalizationKeys[MetadataTagType.category]!.keys;

      expect(categoryCodes, everyElement(hasLength(1)));
      expect(categoryCodes, contains('S'));
      expect(
        const MetadataTag(
          type: MetadataTagType.category,
          code: 'S',
          label: '스포츠',
        ).isSystemDefault,
        isTrue,
      );
    });
  });

  group('MetadataTagLabelValidator', () {
    const existingTags = <MetadataTag>[
      MetadataTag(type: MetadataTagType.category, code: '00', label: '반려동물'),
      MetadataTag(type: MetadataTagType.paymentMethod, code: '00', label: '현금'),
    ];

    test('공백만 입력한 이름을 허용하지 않는다', () {
      final result = MetadataTagLabelValidator.validate(
        type: MetadataTagType.category,
        label: '   ',
        tags: existingTags,
      );

      expect(result, MetadataTagLabelValidation.empty);
    });

    test('같은 태그 종류에서는 공백과 대소문자를 무시하고 중복을 막는다', () {
      final result = MetadataTagLabelValidator.validate(
        type: MetadataTagType.category,
        label: '  반려동물  ',
        tags: existingTags,
      );

      expect(result, MetadataTagLabelValidation.duplicate);
    });

    test('다른 태그 종류의 같은 이름은 허용한다', () {
      final result = MetadataTagLabelValidator.validate(
        type: MetadataTagType.category,
        label: '현금',
        tags: existingTags,
      );

      expect(result, MetadataTagLabelValidation.valid);
    });

    test('수정 중인 태그가 기존 이름을 유지하는 것은 허용한다', () {
      final result = MetadataTagLabelValidator.validate(
        type: MetadataTagType.category,
        label: '반려동물',
        tags: existingTags,
        currentCode: '00',
      );

      expect(result, MetadataTagLabelValidation.valid);
    });

    test('현재 언어와 다른 언어의 시스템 태그 이름도 중복으로 처리한다', () {
      const japaneseTags = <MetadataTag>[
        MetadataTag(type: MetadataTagType.subcategory, code: '_', label: '普段'),
      ];

      final koreanNameResult = MetadataTagLabelValidator.validate(
        type: MetadataTagType.subcategory,
        label: '평상시',
        tags: japaneseTags,
      );
      final japaneseNameResult = MetadataTagLabelValidator.validate(
        type: MetadataTagType.subcategory,
        label: ' 普段 ',
        tags: const <MetadataTag>[],
      );

      expect(koreanNameResult, MetadataTagLabelValidation.duplicate);
      expect(japaneseNameResult, MetadataTagLabelValidation.duplicate);
    });

    test('기본 결제수단도 시스템 태그로 보호한다', () {
      expect(
        const MetadataTag(
          type: MetadataTagType.paymentMethod,
          code: '_c',
          label: '현금',
        ).isSystemDefault,
        isTrue,
      );
    });
  });
}
