//
//  MarkdownText.swift
//  Nio
//
//  Created by Vincent Esche on 4/28/20.
//  Copyright © 2020 Kilian Koeltzsch. All rights reserved.
//

import SwiftUI

import SwiftyMarkdown

struct MarkdownText: View {
	@State var markdownString: String
    @State var desiredHeight: CGFloat = 0.0

    let linkTapped: (URL) -> Void

    var body: some View {
        let attributedString = SwiftyMarkdown(string: markdownString).attributedString()
        return AttributedText(
            attributedString: attributedString,
            height: self.$desiredHeight,
            linkTapped: self.linkTapped
        )
    }
}

struct MarkdownText_Previews: PreviewProvider {
    static var previews: some View {
        let markdownString = #"""
        # [Universal Declaration of Human Rights][udhr]

        ## Article 1.

        All human beings are born free and equal in dignity and rights.
        They are endowed with reason and conscience
        and should act towards one another in a spirit of brotherhood.

        [udhr]: https://www.un.org/en/universal-declaration-human-rights/ "View full version"
        """#
        return MarkdownText(markdownString: markdownString) { url in
            print("Tapped URL:", url)
        }
            .padding(10.0)
            .previewLayout(.sizeThatFits)
    }
}
