// TagChip.swift
// HitomiReader
//
// Pill-shaped tag chip with color coding by type.
// Female tags show ♀, male tags show ♂.

import SwiftUI

struct TagChip: View {
    let name: String
    let type: TagType
    var isFemale: Bool = false
    var isMale: Bool = false
    var onTap: (() -> Void)? = nil
    
    // MARK: - Tag Type
    enum TagType: String {
        case female
        case male
        case artist
        case group
        case series    // parody/series
        case character
        case tag       // generic tag
        case language
        case type      // gallery type
        
        var color: Color {
            switch self {
            case .female:    return Color(hex: "FF2D78")  // Pink
            case .male:      return Color(hex: "4A9EFF")  // Blue
            case .artist:    return Color(hex: "A855F7")  // Purple
            case .group:     return Color(hex: "F97316")  // Orange
            case .series:    return Color(hex: "22C55E")  // Green
            case .character: return Color(hex: "14B8A6")  // Teal
            case .tag:       return Color(hex: "6B7280")  // Gray
            case .language:  return Color(hex: "EAB308")  // Yellow
            case .type:      return Color(hex: "8B5CF6")  // Violet
            }
        }
        
        var icon: String {
            switch self {
            case .female:    return "♀"
            case .male:      return "♂"
            case .artist:    return ""
            case .group:     return ""
            case .series:    return ""
            case .character: return ""
            case .tag:       return ""
            case .language:  return ""
            case .type:      return ""
            }
        }
    }
    
    var body: some View {
        Button(action: { onTap?() }) {
            HStack(spacing: 4) {
                // Gender symbol prefix
                if isFemale {
                    Text("♀")
                        .font(.caption.weight(.bold))
                        .foregroundColor(TagType.female.color)
                } else if isMale {
                    Text("♂")
                        .font(.caption.weight(.bold))
                        .foregroundColor(TagType.male.color)
                }
                
                Text(name)
                    .font(.caption.weight(.medium))
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(chipColor.opacity(0.2))
            )
            .overlay(
                Capsule()
                    .stroke(chipColor.opacity(0.4), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
    
    /// Determine color based on gender override or tag type
    private var chipColor: Color {
        if isFemale { return TagType.female.color }
        if isMale { return TagType.male.color }
        return type.color
    }
}

// MARK: - Convenience initializer for Gallery tags

extension TagChip {
    /// Create a TagChip from a Tag
    init(tag: Tag, onTap: (() -> Void)? = nil) {
        let isFemale = tag.gender == .female
        let isMale = tag.gender == .male
        
        let tagType: TagType
        if isFemale {
            tagType = .female
        } else if isMale {
            tagType = .male
        } else {
            tagType = .tag
        }
        
        self.name = tag.tag
        self.type = tagType
        self.isFemale = isFemale
        self.isMale = isMale
        self.onTap = onTap
    }
}

#Preview {
    ScrollView {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tag Chips").font(.title2.bold()).foregroundColor(.white)
            
            FlowLayout(spacing: 8) {
                TagChip(name: "schoolgirl", type: .female, isFemale: true)
                TagChip(name: "glasses", type: .male, isMale: true)
                TagChip(name: "artist name", type: .artist)
                TagChip(name: "group name", type: .group)
                TagChip(name: "series name", type: .series)
                TagChip(name: "character", type: .character)
                TagChip(name: "generic tag", type: .tag)
            }
        }
        .padding()
    }
    .background(Color(hex: "0D0D0D"))
    .preferredColorScheme(.dark)
}

// MARK: - Flow Layout for wrapping tags

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }
    
    private struct LayoutResult {
        var positions: [CGPoint]
        var size: CGSize
    }
    
    private func computeLayout(proposal: ProposedViewSize, subviews: Subviews) -> LayoutResult {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var maxX: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            
            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            
            positions.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            maxX = max(maxX, currentX - spacing)
        }
        
        return LayoutResult(
            positions: positions,
            size: CGSize(width: maxX, height: currentY + lineHeight)
        )
    }
}
