'''@file normalizer_factory.py
Contains the normalizer factory
'''

from . import character, zh_character, aurora4, phones, gp

def factory(normalizer):
    '''get a normalizer class

    Args:
        normalizer_type: the type of normalizer_type

    Returns:
        a normalizer class'''

    if normalizer == 'aurora4':
        return aurora4.normalize
    elif normalizer == 'phones':
        return phones.normalize
    elif normalizer == 'character':
        return character.normalize
    elif normalizer == 'zh_character':
        return zh_character.normalize
    elif normalizer == 'gp':
        return gp.normalize
    else:
        raise Exception('Undefined normalizer: %s' % normalizer)
